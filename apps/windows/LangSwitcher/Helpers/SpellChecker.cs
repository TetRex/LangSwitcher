using System.Runtime.InteropServices;

namespace LangSwitcher.Helpers;

/// <summary>
/// Wraps the Windows Spell Checking API (ISpellCheckerFactory / ISpellChecker).
/// Falls back gracefully when the COM server is unavailable.
/// </summary>
public sealed class SpellChecker : IDisposable
{
    // ── COM interfaces ────────────────────────────────────────────────────────

    [ComImport, Guid("8E018A9D-2415-4677-BF08-794EA61F94BB")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISpellCheckerFactory
    {
        [PreserveSig] int get_SupportedLanguages(out IEnumString value);
        [PreserveSig] int IsSupported([MarshalAs(UnmanagedType.LPWStr)] string languageTag, [MarshalAs(UnmanagedType.Bool)] out bool value);
        [PreserveSig] int CreateSpellChecker([MarshalAs(UnmanagedType.LPWStr)] string languageTag, out ISpellChecker value);
    }

    [ComImport, Guid("B6FD0B71-E2BC-4653-8D05-F197E412770B")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISpellChecker
    {
        [PreserveSig] int get_LanguageTag([MarshalAs(UnmanagedType.LPWStr)] out string value);
        [PreserveSig] int Check([MarshalAs(UnmanagedType.LPWStr)] string text, out IEnumSpellingError value);
        [PreserveSig] int Suggest([MarshalAs(UnmanagedType.LPWStr)] string word, out IEnumString value);
        [PreserveSig] int Add([MarshalAs(UnmanagedType.LPWStr)] string word);
        [PreserveSig] int Ignore([MarshalAs(UnmanagedType.LPWStr)] string word);
        [PreserveSig] int AutoCorrect([MarshalAs(UnmanagedType.LPWStr)] string from, [MarshalAs(UnmanagedType.LPWStr)] string to);
        [PreserveSig] int GetOptionValue([MarshalAs(UnmanagedType.LPWStr)] string optionId, out byte value);
        [PreserveSig] int get_OptionIds(out IEnumString value);
        [PreserveSig] int get_Id([MarshalAs(UnmanagedType.LPWStr)] out string value);
        [PreserveSig] int get_LocalizedName([MarshalAs(UnmanagedType.LPWStr)] out string value);
        [PreserveSig] int add_SpellCheckerChanged(IntPtr handler, out uint eventCookie);
        [PreserveSig] int remove_SpellCheckerChanged(uint eventCookie);
        [PreserveSig] int GetOptionDescription([MarshalAs(UnmanagedType.LPWStr)] string optionId, out IntPtr value);
        [PreserveSig] int ComprehensiveCheck([MarshalAs(UnmanagedType.LPWStr)] string text, out IEnumSpellingError value);
    }

    [ComImport, Guid("803E3BD4-2828-4410-8290-418D1D73C762")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IEnumSpellingError
    {
        // Returns S_OK (0) + a valid error when a misspelling is found;
        // Returns S_FALSE (1) when no more errors (word is correct).
        [PreserveSig] int Next(out IntPtr value); // IntPtr avoids null COM ptr marshaling issues
    }

    [ComImport, Guid("00000101-0000-0000-C000-000000000046")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IEnumString
    {
        [PreserveSig] int Next(uint celt, [MarshalAs(UnmanagedType.LPWStr)] out string rgelt, out uint pceltFetched);
        [PreserveSig] int Skip(uint celt);
        [PreserveSig] int Reset();
        [PreserveSig] int Clone(out IEnumString ppenum);
    }

    // CLSID for SpellCheckerFactory
    private static readonly Guid ClsidSpellCheckerFactory = new("7AB36653-1796-484B-BDFA-E74F1DB7C1DC");

    // ── State ─────────────────────────────────────────────────────────────────

    private ISpellCheckerFactory? _factory;
    private readonly Dictionary<string, ISpellChecker?> _checkers = new();

    /// True when the Windows spell-check COM server initialised successfully.
    public bool IsAvailable => _factory != null;

    private static readonly string[] CyrillicLanguages = ["ru-RU", "uk-UA"];
    private static readonly string[] EnglishLanguages  = ["en-US", "en-GB"];

    public SpellChecker()
    {
        try
        {
            // Use Activator.CreateInstance for safer COM activation than [ComImport] new()
            var type = Type.GetTypeFromCLSID(ClsidSpellCheckerFactory, throwOnError: true)!;
            _factory = (ISpellCheckerFactory)Activator.CreateInstance(type)!;
            Logger.Log($"SpellChecker: COM factory created OK.");

            // Log which languages are actually supported
            foreach (var lang in CyrillicLanguages.Concat(EnglishLanguages))
            {
                _factory.IsSupported(lang, out bool supported);
                Logger.Log($"  language '{lang}' supported={supported}");
            }
        }
        catch (Exception ex)
        {
            _factory = null;
            Logger.Log($"SpellChecker: COM factory failed — {ex.GetType().Name}: {ex.Message}");
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public bool IsValidEnglishWord(string word)  => IsValidIn(word, EnglishLanguages);
    public bool IsValidCyrillicWord(string word) => IsValidIn(word, CyrillicLanguages);

    public string? CyrillicWordLanguage(string word)
    {
        if (_factory == null) return null;
        foreach (var lang in CyrillicLanguages)
        {
            var checker = GetChecker(lang);
            if (checker != null && IsWordValid(checker, word))
                return lang;
        }
        return null;
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    private bool IsValidIn(string word, string[] languages)
    {
        // When the factory is unavailable we cannot validate — return false so that
        // the correction pipeline can still run based on character mapping alone.
        // (Returning true would silently block all corrections.)
        if (_factory == null) return false;

        foreach (var lang in languages)
        {
            var checker = GetChecker(lang);
            if (checker != null && IsWordValid(checker, word))
                return true;
        }
        return false;
    }

    private static bool IsWordValid(ISpellChecker checker, string word)
    {
        try
        {
            int hr = checker.Check(word, out var errors);
            if (hr != 0 || errors == null) return false;

            // Next() returns S_OK (0) if a spelling error was found,
            // S_FALSE (1) if there are no more errors (i.e. word is correct).
            int nextHr = errors.Next(out _);
            Marshal.ReleaseComObject(errors);
            return nextHr != 0; // S_FALSE → no errors → valid
        }
        catch { return false; }
    }

    private ISpellChecker? GetChecker(string lang)
    {
        if (_checkers.TryGetValue(lang, out var existing)) return existing;

        ISpellChecker? checker = null;
        try
        {
            if (_factory != null)
            {
                _factory.IsSupported(lang, out bool supported);
                if (supported)
                {
                    _factory.CreateSpellChecker(lang, out checker);
                    Logger.Log($"SpellChecker: created checker for '{lang}'");
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Log($"SpellChecker: CreateSpellChecker('{lang}') failed — {ex.Message}");
            checker = null;
        }

        _checkers[lang] = checker;
        return checker;
    }

    public void Dispose()
    {
        foreach (var c in _checkers.Values)
            if (c != null) Marshal.ReleaseComObject(c);
        _checkers.Clear();
        if (_factory != null) Marshal.ReleaseComObject(_factory);
        _factory = null;
    }
}
