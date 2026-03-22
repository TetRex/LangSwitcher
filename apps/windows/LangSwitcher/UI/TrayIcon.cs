using LangSwitcher.Core;
using LangSwitcher.Helpers;
using LangSwitcher.Models;

namespace LangSwitcher.UI;

/// <summary>
/// System-tray icon with context menu. No main window on startup.
/// </summary>
public sealed class TrayIcon : IDisposable
{
    private readonly AppSettings _settings;
    private readonly KeyboardHook _hook;
    private readonly NotifyIcon _notifyIcon;
    private SettingsForm? _settingsForm;

    private ToolStripMenuItem _enableItem = null!;

    public TrayIcon(AppSettings settings, KeyboardHook hook)
    {
        _settings = settings;
        _hook     = hook;

        _notifyIcon = new NotifyIcon
        {
            Text    = BuildTooltip(),
            Visible = true,
        };

        LoadIcon();
        BuildContextMenu();

        _hook.CorrectionMade += OnCorrectionMade;
    }

    // ── Icon ──────────────────────────────────────────────────────────────────

    private void LoadIcon()
    {
        // Try to load embedded icon resource; fall back to SystemIcons.Application
        try
        {
            var asm    = typeof(TrayIcon).Assembly;
            var name   = asm.GetManifestResourceNames()
                            .FirstOrDefault(n => n.EndsWith("appicon.ico", StringComparison.OrdinalIgnoreCase));
            if (name != null)
            {
                using var stream = asm.GetManifestResourceStream(name)!;
                _notifyIcon.Icon = new Icon(stream);
                return;
            }
        }
        catch { }
        _notifyIcon.Icon = SystemIcons.Application;
    }

    // ── Context menu ──────────────────────────────────────────────────────────

    private void BuildContextMenu()
    {
        _enableItem = new ToolStripMenuItem("Enabled", null, OnToggleEnabled)
        {
            Checked = _settings.IsEnabled,
            CheckOnClick = true,
        };

        var settingsItem = new ToolStripMenuItem("Settings…", null, OnOpenSettings);
        var aboutItem    = new ToolStripMenuItem("About", null, OnAbout);
        var quitItem     = new ToolStripMenuItem("Quit", null, OnQuit);

        var menu = new ContextMenuStrip();
        menu.Items.Add(_enableItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(settingsItem);
        menu.Items.Add(aboutItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(quitItem);

        _notifyIcon.ContextMenuStrip = menu;
        _notifyIcon.DoubleClick += OnOpenSettings;
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    private void OnToggleEnabled(object? sender, EventArgs e)
    {
        _settings.IsEnabled = _enableItem.Checked;
        _settings.Save();
        UpdateTooltip();
    }

    private void OnOpenSettings(object? sender, EventArgs e)
    {
        if (_settingsForm == null || _settingsForm.IsDisposed)
        {
            _settingsForm = new SettingsForm(_settings);
            _settingsForm.FormClosed += (_, _) => _settingsForm = null;
        }
        _settingsForm.Show();
        _settingsForm.BringToFront();
    }

    private void OnAbout(object? sender, EventArgs e)
    {
        MessageBox.Show(
            $"LangSwitcher\n\nAutomatically fixes Cyrillic ↔ English keyboard layout mistakes.\n\nCorrections made: {_settings.CorrectionCount}",
            "About LangSwitcher",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
    }

    private void OnQuit(object? sender, EventArgs e)
    {
        _settings.Save();
        Application.Exit();
    }

    private void OnCorrectionMade(string original, string corrected)
    {
        UpdateTooltip();
    }

    // ── Tooltip ───────────────────────────────────────────────────────────────

    private void UpdateTooltip() =>
        _notifyIcon.Text = BuildTooltip();

    private string BuildTooltip()
    {
        var status = _settings.IsEnabled ? "Active" : "Disabled";
        return $"LangSwitcher — {status} | Corrections: {_settings.CorrectionCount}";
    }

    // ── IDisposable ───────────────────────────────────────────────────────────

    public void Dispose()
    {
        _hook.CorrectionMade -= OnCorrectionMade;
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _settingsForm?.Dispose();
    }
}
