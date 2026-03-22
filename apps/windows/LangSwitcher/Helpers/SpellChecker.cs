using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace LangSwitcher.Helpers;

/// <summary>
/// Wraps the Windows Spell Checking API (ISpellCheckerFactory / ISpellChecker).
/// Falls back to "always valid" when the API is unavailable (e.g. older Windows).
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
        [PreserveSig] int add_SpellCheckerChanged(object handler, out uint eventCookie);
        [PreserveSig] int remove_SpellCheckerChanged(uint eventCookie);
        [PreserveSig] int GetOptionDescription([MarshalAs(UnmanagedType.LPWStr)] string optionId, out object value);
        [PreserveSig] int ComprehensiveCheck([MarshalAs(UnmanagedType.LPWStr)] string text, out IEnumSpellingError value);
    }

    [ComImport, Guid("803E3BD4-2828-4410-8290-418D1D73C762")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IEnumSpellingError
    {
        [PreserveSig] int Next(out ISpellingError value);
    }

    [ComImport, Guid("B7C82D61-FBE8-4B47-9B27-6C0D2E0DE0A3")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISpellingError
    {
        [PreserveSig] int get_StartIndex(out uint value);
        [PreserveSig] int get_Length(out uint value);
        [PreserveSig] int get_CorrectiveAction(out int value);
        [PreserveSig] int get_Replacement([MarshalAs(UnmanagedType.LPWStr)] out string value);
    }

    [ComImport, Guid("00000101-0000-0000-C000-000000000046")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IEnumString
    {
        [PreserveSig] int Next(uint celt, [MarshalAs(UnmanagedType.LPWStr, SizeParamIndex = 0)] out string rgelt, out uint pceltFetched);
        [PreserveSig] int Skip(uint celt);
        [PreserveSig] int Reset();
        [PreserveSig] int Clone(out IEnumString ppenum);
    }

    [ComImport, Guid("7AB36653-1796-484B-BDFA-E74F1DB7C1DC")]
    [ClassInterface(ClassInterfaceType.None)]
    private class SpellCheckerFactoryClass { }

    // ── State ─────────────────────────────────────────────────────────────────

    private ISpellCheckerFactory? _factory;
    private readonly Dictionary<string, ISpellChecker?> _checkers = new();

    private static readonly string[] CyrillicLanguages = ["ru-RU", "uk-UA", "ru", "uk"];
    private static readonly string[] EnglishLanguages  = ["en-US", "en-GB", "en"];

    public SpellChecker()
    {
        try
        {
            _factory = (ISpellCheckerFactory)new SpellCheckerFactoryClass();
        }
        catch
        {
            _factory = null; // Windows spell checking not available
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public bool IsValidEnglishWord(string word)  => IsValidIn(word, EnglishLanguages);
    public bool IsValidCyrillicWord(string word) => IsValidIn(word, CyrillicLanguages);

    /// Returns language tag ("ru-RU" / "uk-UA" / …) of first Cyrillic language match, or null.
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
        if (_factory == null) return true; // can't check → assume valid (no false corrections)
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
            if (checker.Check(word, out var errors) != 0) return false;
            // No errors → word is valid
            var hr = errors.Next(out _);
            return hr != 0; // S_FALSE (1) = no more errors = word is valid
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
                    _factory.CreateSpellChecker(lang, out checker);
            }
        }
        catch { checker = null; }

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
