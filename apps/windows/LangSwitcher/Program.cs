using LangSwitcher.Core;
using LangSwitcher.Helpers;
using LangSwitcher.Models;
using LangSwitcher.UI;

namespace LangSwitcher;

internal static class Program
{
    [STAThread]
    static void Main()
    {
        // Single-instance guard
        using var mutex = new System.Threading.Mutex(true, "LangSwitcher_SingleInstance", out bool createdNew);
        if (!createdNew)
        {
            MessageBox.Show("LangSwitcher is already running.", "LangSwitcher",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        ApplicationConfiguration.Initialize();

        var settings  = AppSettings.Load();
        var spell     = new SpellChecker();
        var converter = new LayoutConverter(spell);
        var hook      = new KeyboardHook(settings, converter);

        hook.Install();

        if (!spell.IsAvailable)
        {
            MessageBox.Show(
                "The Windows Spell Checker COM service could not be initialised.\n\n" +
                "LangSwitcher will still correct words based on character mapping alone " +
                "(no false-positive guard). Install Russian/Ukrainian language packs in " +
                "Windows Settings → Time & Language → Language & Region and restart the app.",
                "LangSwitcher — Spell Checker Unavailable",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }

        using var tray = new TrayIcon(settings, hook);

        Application.Run(); // message loop — no main window

        hook.Uninstall();
        spell.Dispose();

        settings.Save();
    }
}
