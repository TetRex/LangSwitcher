using System.Runtime.InteropServices;

namespace LangSwitcher.Helpers;

/// <summary>
/// Switches the active keyboard layout for the foreground window
/// using LoadKeyboardLayout + PostMessage(WM_INPUTLANGCHANGEREQUEST).
/// </summary>
public static class LayoutSwitcher
{
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] private static extern IntPtr GetKeyboardLayout(uint idThread);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags);
    [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] private static extern IntPtr ActivateKeyboardLayout(IntPtr hkl, uint Flags);

    private const uint WM_INPUTLANGCHANGEREQUEST = 0x0050;
    private const uint KLF_ACTIVATE = 0x00000001;

    // Common KLID strings: https://learn.microsoft.com/en-us/windows/win32/intl/language-identifier-constants-and-strings
    private const string KlidEnUS  = "00000409"; // English (US)
    private const string KlidRuRU  = "00000419"; // Russian
    private const string KlidUkUA  = "00000422"; // Ukrainian

    public static void SwitchToEnglish()   => Switch(KlidEnUS);
    public static void SwitchToRussian()   => Switch(KlidRuRU);
    public static void SwitchToUkrainian() => Switch(KlidUkUA);

    public static void SwitchToCyrillic(string? preferredLanguage = null)
    {
        if (preferredLanguage != null &&
            (preferredLanguage.StartsWith("uk", StringComparison.OrdinalIgnoreCase)))
            SwitchToUkrainian();
        else
            SwitchToRussian();
    }

    private static void Switch(string klid)
    {
        try
        {
            var hkl = LoadKeyboardLayout(klid, KLF_ACTIVATE);
            if (hkl == IntPtr.Zero) return;

            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return;

            PostMessage(hwnd, WM_INPUTLANGCHANGEREQUEST, IntPtr.Zero, hkl);
        }
        catch { /* best-effort */ }
    }
}
