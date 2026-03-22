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

        using var tray = new TrayIcon(settings, hook);

        Application.Run(); // message loop — no main window

        hook.Uninstall();
        spell.Dispose();
        settings.Save();
    }
}
