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
        // S_OK (0) = spelling error found; S_FALSE (1) = no more errors = word is correct
        [PreserveSig] int Next(out IntPtr spellingError);
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

    private static readonly Guid ClsidSpellCheckerFactory = new("7AB36653-1796-484B-BDFA-E74F1DB7C1DC");

    // ── State ─────────────────────────────────────────────────────────────────

    private ISpellCheckerFactory? _factory;
    private readonly Dictionary<string, ISpellChecker?> _checkers = new();

    /// True when the Windows spell-check COM server initialised and a self-test passed.
    public bool IsAvailable { get; private set; }

    private static readonly string[] CyrillicLanguages = ["ru-RU", "uk-UA"];
    private static readonly string[] EnglishLanguages  = ["en-US", "en-GB"];

    public SpellChecker()
    {
        Logger.Log("SpellChecker: initialising…");
        try
        {
            var type = Type.GetTypeFromCLSID(ClsidSpellCheckerFactory, throwOnError: true)!;
            _factory = (ISpellCheckerFactory)Activator.CreateInstance(type)!;
            Logger.Log("SpellChecker: COM factory OK");
        }
        catch (Exception ex)
        {
            Logger.Log($"SpellChecker: COM factory FAILED — {ex.GetType().Name}: {ex.Message}");
            _factory = null;
        }

        if (_factory != null)
        {
            // Log which languages the system supports
            foreach (var lang in CyrillicLanguages.Concat(EnglishLanguages))
            {
                try
                {
                    _factory.IsSupported(lang, out bool supported);
                    Logger.Log($"  lang '{lang}' supported={supported}");
                }
                catch (Exception ex) { Logger.Log($"  lang '{lang}' check threw: {ex.Message}"); }
            }

            // Self-test: "hello" must pass en-US, "привет" must pass ru-RU
            RunSelfTest();
        }

        IsAvailable = _factory != null;
        Logger.Log($"SpellChecker: IsAvailable={IsAvailable}");
    }

    private void RunSelfTest()
    {
        bool enOk  = TestWord("hello",  "en-US");
        bool ruOk  = TestWord("привет", "ru-RU");
        Logger.Log($"SpellChecker self-test: 'hello'/en-US={enOk}  'привет'/ru-RU={ruOk}");

        // If neither works, mark unavailable even though factory exists
        if (!enOk && !ruOk) _factory = null;
    }

    private bool TestWord(string word, string lang)
    {
        try
        {
            _factory!.IsSupported(lang, out bool supported);
            if (!supported) { Logger.Log($"  TestWord: '{lang}' not supported"); return false; }

            _factory.CreateSpellChecker(lang, out var checker);
            if (checker == null) { Logger.Log($"  TestWord: checker for '{lang}' is null"); return false; }

            int checkHr = checker.Check(word, out var errors);
            Logger.Log($"  TestWord '{word}'/'{lang}': Check() hr=0x{checkHr:X8} errors={(errors != null ? "ok" : "null")}");

            if (checkHr != 0 || errors == null)
            {
                Marshal.ReleaseComObject(checker);
                return false;
            }

            int nextHr = errors.Next(out var ptr);
            Logger.Log($"  TestWord '{word}'/'{lang}': Next() hr=0x{nextHr:X8} (0=error found, 1=no errors=valid)");

            // Only release if Next() actually returned an error object (S_OK).
            if (nextHr == 0 && ptr != IntPtr.Zero) Marshal.Release(ptr);
            Marshal.ReleaseComObject(errors);
            Marshal.ReleaseComObject(checker);

            return nextHr != 0; // S_FALSE (1) = no spelling errors = word is valid
        }
        catch (Exception ex)
        {
            Logger.Log($"  TestWord '{word}'/'{lang}' threw: {ex.GetType().Name}: {ex.Message}");
            return false;
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
            int checkHr = checker.Check(word, out var errors);
            Logger.Log($"    Check('{word}') hr=0x{checkHr:X8} errors={(errors != null ? "ok" : "null")}");
            if (checkHr != 0 || errors == null) return false;

            int nextHr = errors.Next(out var ptr);
            Logger.Log($"    Next() hr=0x{nextHr:X8} (1=S_FALSE=valid, 0=S_OK=has errors)");
            // Only release the ISpellingError object when Next() returned S_OK (0),
            // meaning it actually gave us an error. On S_FALSE the ptr is undefined —
            // calling Marshal.Release on it would corrupt the COM server state.
            if (nextHr == 0 && ptr != IntPtr.Zero) Marshal.Release(ptr);
            Marshal.ReleaseComObject(errors);

            return nextHr != 0; // S_FALSE (1) = no errors = valid
        }
        catch (Exception ex)
        {
            Logger.Log($"    IsWordValid('{word}') threw: {ex.GetType().Name}: {ex.Message}");
            return false;
        }
    }

    private ISpellChecker? GetChecker(string lang)
    {
        if (_checkers.TryGetValue(lang, out var existing))
        {
            Logger.Log($"  GetChecker('{lang}'): cached, ok={existing != null}");
            return existing;
        }

        ISpellChecker? checker = null;
        try
        {
            if (_factory != null)
            {
                _factory.IsSupported(lang, out bool supported);
                Logger.Log($"  GetChecker('{lang}'): supported={supported}");
                if (supported)
                {
                    _factory.CreateSpellChecker(lang, out checker);
                    Logger.Log($"  GetChecker('{lang}'): checker={(checker != null ? "ok" : "null")}");
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Log($"  GetChecker('{lang}') threw: {ex.GetType().Name}: {ex.Message}");
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
