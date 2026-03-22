using System.Runtime.InteropServices;

namespace LangSwitcher.Core;

/// <summary>
/// Erases the mistyped word with synthetic Backspace keystrokes,
/// then injects the corrected text using SendInput.
/// </summary>
public static class TextReplacer
{
    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public INPUTUNION u;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUTUNION
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    private const uint INPUT_KEYBOARD   = 1;
    private const uint KEYEVENTF_KEYUP  = 0x0002;
    private const uint KEYEVENTF_UNICODE = 0x0004;
    private const ushort VK_BACK        = 0x08;

    // Sentinel put in dwExtraInfo to let KeyboardHook ignore our own injected events.
    public const nint OwnEventSentinel = 0x4C53; // 'LS'

    [DllImport("user32.dll")] private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    /// <summary>
    /// Deletes <paramref name="charCount"/> characters then types <paramref name="replacement"/>.
    /// Optionally appends a trailing character (Space or Enter from the original trigger event).
    /// </summary>
    /// Returns the number of events successfully injected by SendInput (0 = blocked).
    public static uint Replace(int charCount, string replacement, char? trailingChar = null)
    {
        var inputs = BuildInputs(charCount, replacement, trailingChar);
        if (inputs.Length == 0) return 0;
        return SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
    }

    private static INPUT[] BuildInputs(int backspaceCount, string text, char? trailingChar)
    {
        // Each key needs a down + up event.
        // Backspace: 1 VK event per char × 2 (down+up)
        // Unicode text: each UTF-16 unit × 2
        var full = trailingChar.HasValue ? text + trailingChar.Value : text;
        int unicodeUnits = full.Length; // BMP-only assumption (sufficient for Cyrillic + ASCII)

        int total = backspaceCount * 2 + unicodeUnits * 2;
        var inputs = new INPUT[total];
        int idx = 0;

        // Backspaces
        for (int i = 0; i < backspaceCount; i++)
        {
            inputs[idx++] = MakeVkInput(VK_BACK, 0);
            inputs[idx++] = MakeVkInput(VK_BACK, KEYEVENTF_KEYUP);
        }

        // Unicode characters
        foreach (var ch in full)
        {
            inputs[idx++] = MakeUnicodeInput(ch, 0);
            inputs[idx++] = MakeUnicodeInput(ch, KEYEVENTF_KEYUP);
        }

        return inputs;
    }

    private static INPUT MakeVkInput(ushort vk, uint flags) => new()
    {
        type = INPUT_KEYBOARD,
        u = new INPUTUNION
        {
            ki = new KEYBDINPUT
            {
                wVk = vk,
                wScan = 0,
                dwFlags = flags,
                time = 0,
                dwExtraInfo = OwnEventSentinel,
            }
        }
    };

    private static INPUT MakeUnicodeInput(char ch, uint flags) => new()
    {
        type = INPUT_KEYBOARD,
        u = new INPUTUNION
        {
            ki = new KEYBDINPUT
            {
                wVk = 0,
                wScan = ch,
                dwFlags = KEYEVENTF_UNICODE | flags,
                time = 0,
                dwExtraInfo = OwnEventSentinel,
            }
        }
    };
}
