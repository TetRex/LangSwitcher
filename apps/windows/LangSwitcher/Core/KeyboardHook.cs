using System.Runtime.InteropServices;
using LangSwitcher.Helpers;
using LangSwitcher.Models;
using static LangSwitcher.Helpers.Logger;

namespace LangSwitcher.Core;

/// <summary>
/// Installs a WH_KEYBOARD_LL system-wide hook, buffers keystrokes,
/// and triggers layout correction on Space / Enter / punctuation.
/// </summary>
public sealed class KeyboardHook : IDisposable
{
    // ── Win32 ─────────────────────────────────────────────────────────────────

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll")] private static extern short GetKeyState(int nVirtKey);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public nint dwExtraInfo;
    }

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN     = 0x0100;
    private const int WM_SYSKEYDOWN  = 0x0104;

    // Virtual key codes
    private const uint VK_BACK   = 0x08;
    private const uint VK_RETURN = 0x0D;
    private const uint VK_SPACE  = 0x20;
    private const uint VK_ESCAPE = 0x1B;
    private const uint VK_LEFT   = 0x25;
    private const uint VK_UP     = 0x26;
    private const uint VK_RIGHT  = 0x27;
    private const uint VK_DOWN   = 0x28;
    private const uint VK_DELETE = 0x2E;
    private const uint VK_HOME   = 0x24;
    private const uint VK_END    = 0x23;
    private const uint VK_PRIOR  = 0x21; // Page Up
    private const uint VK_NEXT   = 0x22; // Page Down
    private const uint VK_TAB    = 0x09;

    // Modifier VKs
    private const uint VK_SHIFT   = 0x10;
    private const uint VK_CONTROL = 0x11;
    private const uint VK_MENU    = 0x12; // Alt
    private const uint VK_LMENU   = 0xA4;
    private const uint VK_RMENU   = 0xA5;
    private const uint VK_LWIN    = 0x5B;
    private const uint VK_RWIN    = 0x5C;
    private const uint VK_CAPITAL = 0x14; // CapsLock

    private static readonly HashSet<uint> NonCharKeys = new()
    {
        VK_ESCAPE, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN,
        VK_DELETE, VK_HOME, VK_END, VK_PRIOR, VK_NEXT,
        VK_SHIFT, VK_CONTROL, VK_MENU, VK_LMENU, VK_RMENU,
        VK_LWIN, VK_RWIN, VK_CAPITAL, VK_TAB,
        // F1-F24
        0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,
        0x78,0x79,0x7A,0x7B,0x7C,0x7D,0x7E,0x7F,
        0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87,
    };

    // ── State ─────────────────────────────────────────────────────────────────

    private readonly AppSettings _settings;
    private readonly LayoutConverter _converter;
    private bool SpellCheckAvailable => _converter.SpellCheckAvailable;
    private readonly WordBuffer _buffer = new();
    private readonly LowLevelKeyboardProc _proc; // keep alive to prevent GC
    private IntPtr _hook = IntPtr.Zero;
    // Force-convert double-tap tracking
    private DateTime _lastForceConvertTime = DateTime.MinValue;
    private const double DoubleTapIntervalMs = 400;

    // ── Events ────────────────────────────────────────────────────────────────

    /// Fired when a correction is made. Args: (original, corrected).
    public event Action<string, string>? CorrectionMade;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    public KeyboardHook(AppSettings settings, LayoutConverter converter)
    {
        _settings  = settings;
        _converter = converter;
        _proc = HookCallback; // keep delegate alive
    }

    public void Install()
    {
        if (_hook != IntPtr.Zero) return;
        using var curProcess = System.Diagnostics.Process.GetCurrentProcess();
        using var curModule  = curProcess.MainModule!;
        _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc,
                                 GetModuleHandle(curModule.ModuleName!), 0);
    }

    public void Uninstall()
    {
        if (_hook == IntPtr.Zero) return;
        UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
    }

    public void Dispose() => Uninstall();

    // ── Hook callback ─────────────────────────────────────────────────────────

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode < 0 || !_settings.IsEnabled)
            return CallNextHookEx(_hook, nCode, wParam, lParam);

        bool isKeyDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
        if (!isKeyDown)
            return CallNextHookEx(_hook, nCode, wParam, lParam);

        var kbd = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);

        // Ignore events we ourselves injected (sentinel in dwExtraInfo).
        if (kbd.dwExtraInfo == TextReplacer.OwnEventSentinel)
            return CallNextHookEx(_hook, nCode, wParam, lParam);

        uint vk = kbd.vkCode;

        // ── Force-convert shortcut ────────────────────────────────────────────
        bool isForceConvertKey = (int)vk == _settings.ForceConvertKey;
        if (isForceConvertKey)
        {
            bool hasModifierConfig = _settings.ForceConvertModifiers != 0;

            if (hasModifierConfig)
            {
                // Modifier-based: check that required modifiers are held
                if (CurrentModifiers() == _settings.ForceConvertModifiers)
                {
                    TryForceConvert();
                    // Suppress key
                    return (IntPtr)1;
                }
            }
            else
            {
                // Double-tap mode (no modifiers required)
                if (CurrentModifiers() == 0)
                {
                    var now = DateTime.UtcNow;
                    if ((now - _lastForceConvertTime).TotalMilliseconds <= DoubleTapIntervalMs)
                    {
                        _lastForceConvertTime = DateTime.MinValue;
                        TryForceConvert();
                        return (IntPtr)1;
                    }
                    _lastForceConvertTime = now;
                    // Let the first tap through
                    return CallNextHookEx(_hook, nCode, wParam, lParam);
                }
            }
        }

        // ── Skip command combos (Ctrl+X, Alt+X, Win+X …) ─────────────────────
        uint mods = CurrentModifiers();
        // Shift alone is fine (produces uppercase) — mask it out for this check
        uint commandMods = mods & ~(uint)ModifierFlags.Shift;
        if (commandMods != 0)
        {
            _buffer.Clear(); // cursor state may change
            return CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        // ── Backspace ─────────────────────────────────────────────────────────
        if (vk == VK_BACK)
        {
            _buffer.RemoveLast();
            return CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        // ── Space / Enter ─────────────────────────────────────────────────────
        if (vk == VK_SPACE || vk == VK_RETURN)
        {
            var word = _buffer.Current;
            _buffer.Clear();

            Log($"WORD: '{word}' (len={word.Length})");

            if (string.IsNullOrEmpty(word))
                return CallNextHookEx(_hook, nCode, wParam, lParam);

            char trailing = vk == VK_RETURN ? '\n' : ' ';

            // 1. Text shortcut expansion
            var expansion = FindShortcutExpansion(word);
            if (expansion != null)
            {
                Log($"  → shortcut expansion: '{expansion}'");
                Correct(word, expansion, trailing, switchLayout: false);
                return (IntPtr)1;
            }

            // 2. Cyrillic → English
            // Guard: skip if the word is already a valid Cyrillic word (don't fix what's right).
            // When spell check is unavailable, only skip if the word is pure ASCII (not Cyrillic at all).
            bool validCyrillic = SpellCheckAvailable
                ? _converter.IsValidCyrillicWordConsideringLatinOverlap(word)
                : word.All(c => c < 128); // ASCII-only → definitely not a Cyrillic mistype
            Log($"  validCyrillic={validCyrillic} (spellOk={SpellCheckAvailable})");
            if (!validCyrillic)
            {
                var english = LayoutConverter.ConvertIncludingLatin(word);
                // When spell check works, validate the English result.
                // When unavailable, accept any clean conversion (all chars mapped).
                bool validEnglish = english != null &&
                    (SpellCheckAvailable ? _converter.IsValidEnglishWord(english) : true);
                Log($"  cyrToEn='{english}' validEnglish={validEnglish}");
                if (english != null && validEnglish)
                {
                    Correct(word, english, trailing, switchLayout: true, cyrillicToEn: true);
                    return (IntPtr)1;
                }
            }

            // 3. English → Cyrillic
            // Guard: skip if the word is already valid English.
            // When spell check is unavailable, skip only obvious English words (contains vowels).
            bool validEnWord = SpellCheckAvailable
                ? _converter.IsValidEnglishWord(word)
                : HasEnglishVowel(word); // real English words almost always have vowels
            Log($"  validEnglish(original)={validEnWord} (spellOk={SpellCheckAvailable})");
            if (!validEnWord)
            {
                var cyrillic = _converter.ConvertEnglishMistypeToValidCyrillic(word);
                Log($"  enToCyr='{cyrillic}'");
                if (cyrillic != null)
                {
                    Correct(word, cyrillic, trailing, switchLayout: true, cyrillicToEn: false);
                    return (IntPtr)1;
                }
            }

            return CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        // ── Navigation / non-character keys ───────────────────────────────────
        if (NonCharKeys.Contains(vk))
        {
            _buffer.Clear();
            return CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        // ── Ordinary character key ────────────────────────────────────────────
        var ch = VkToChar(vk, kbd.scanCode);
        if (ch != '\0')
            _buffer.Append(ch);

        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    // ── Force convert (mid-word) ──────────────────────────────────────────────

    private void TryForceConvert()
    {
        var word = _buffer.Current;
        _buffer.Clear();

        var english = LayoutConverter.ConvertIncludingLatin(word);
        if (english != null)
        {
            TextReplacer.Replace(word.Length, english, null);

            if (_settings.AutoSwitchLayout)
                LayoutSwitcher.SwitchToEnglish();

            _settings.CorrectionCount++;
            _settings.Save();
            CorrectionMade?.Invoke(word, english);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static readonly HashSet<char> EnglishVowels = new("aeiouAEIOU");

    /// Heuristic: real English words almost always contain at least one vowel.
    /// Used as a cheap "is this plausibly English?" guard when the spell checker
    /// is unavailable, to avoid correcting things like "ghbdtn" (no vowels).
    private static bool HasEnglishVowel(string word) =>
        word.Any(c => EnglishVowels.Contains(c));

    // ── Correction ────────────────────────────────────────────────────────────

    private void Correct(string original, string replacement, char trailing,
                         bool switchLayout, bool cyrillicToEn = false)
    {
        TextReplacer.Replace(original.Length, replacement, trailing);

        if (switchLayout && _settings.AutoSwitchLayout)
        {
            if (cyrillicToEn)
                LayoutSwitcher.SwitchToEnglish();
            else
            {
                var lang = _converter.CyrillicWordLanguage(replacement);
                LayoutSwitcher.SwitchToCyrillic(lang);
            }
        }

        _settings.CorrectionCount++;
        _settings.Save();
        CorrectionMade?.Invoke(original, replacement);
    }

    // ── Text shortcuts ────────────────────────────────────────────────────────

    private string? FindShortcutExpansion(string trigger)
    {
        foreach (var s in _settings.TextShortcuts)
            if (s.Trigger == trigger) return s.Expansion;
        return null;
    }

    // ── Modifier helpers ──────────────────────────────────────────────────────

    [Flags]
    private enum ModifierFlags : uint
    {
        None    = 0,
        Shift   = 1,
        Control = 2,
        Alt     = 4,
        Win     = 8,
    }

    private static uint CurrentModifiers()
    {
        uint mods = 0;
        if ((GetKeyState(0x10) & 0x8000) != 0) mods |= (uint)ModifierFlags.Shift;   // VK_SHIFT
        if ((GetKeyState(0x11) & 0x8000) != 0) mods |= (uint)ModifierFlags.Control; // VK_CONTROL
        if ((GetKeyState(0x12) & 0x8000) != 0) mods |= (uint)ModifierFlags.Alt;     // VK_MENU
        if ((GetKeyState(0x5B) & 0x8000) != 0 ||
            (GetKeyState(0x5C) & 0x8000) != 0) mods |= (uint)ModifierFlags.Win;
        return mods;
    }

    // ── VK → char ─────────────────────────────────────────────────────────────

    // MapVirtualKeyEx with MAPVK_VK_TO_CHAR (2) returns the base Unicode character
    // for the key on the given layout — no keyboard state required, safe in any context.
    [DllImport("user32.dll")] private static extern uint MapVirtualKeyEx(uint uCode, uint uMapType, IntPtr dwhkl);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] private static extern IntPtr GetKeyboardLayout(uint idThread);

    private static char VkToChar(uint vk, uint scan)
    {
        var  hwnd = GetForegroundWindow();
        uint tid  = GetWindowThreadProcessId(hwnd, out _);
        var  hkl  = GetKeyboardLayout(tid);

        // High bit of the return value = dead key: skip those.
        uint code = MapVirtualKeyEx(vk, 2 /* MAPVK_VK_TO_CHAR */, hkl);
        if (code == 0 || (code & 0x80000000) != 0) return '\0';

        char ch = (char)(code & 0xFFFF);

        // Apply Shift / CapsLock for correct case.
        // GetAsyncKeyState is reliable even inside a low-level hook callback.
        bool shift    = (GetAsyncKeyState(0x10) & 0x8000) != 0; // VK_SHIFT
        bool capsLock = (GetKeyState(0x14) & 0x0001) != 0;       // VK_CAPITAL toggle bit
        bool upper    = shift ^ capsLock;

        if (char.IsLetter(ch))
            return upper ? char.ToUpper(ch) : char.ToLower(ch);

        // Shift changes punctuation characters on standard layouts.
        if (upper)
        {
            return ch switch
            {
                '`'  => '~',  '1' => '!',  '2' => '@',  '3' => '#',
                '4'  => '$',  '5' => '%',  '6' => '^',  '7' => '&',
                '8'  => '*',  '9' => '(',  '0' => ')',  '-' => '_',
                '='  => '+',  '[' => '{',  ']' => '}',  '\\' => '|',
                ';'  => ':',  '\'' => '"', ',' => '<',  '.' => '>',
                '/'  => '?',
                _ => ch,
            };
        }

        return ch;
    }
}
