using System.Text.Json;
using LangSwitcher.Models;

namespace LangSwitcher.Models;

public class AppSettings
{
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "LangSwitcher", "settings.json");

    public bool IsEnabled { get; set; } = true;
    public bool AutoSwitchLayout { get; set; } = true;
    public int CorrectionCount { get; set; } = 0;

    // Force-convert hotkey: virtual key code + modifiers bitmask
    // Default: Left Alt key (VK_LMENU = 0xA4), no modifiers required (double-tap mode)
    public int ForceConvertKey { get; set; } = 0xA4; // VK_LMENU
    public uint ForceConvertModifiers { get; set; } = 0; // 0 = double-tap mode

    public List<TextShortcut> TextShortcuts { get; set; } = new();

    // ── Persistence ──────────────────────────────────────────────────────────

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var json = File.ReadAllText(SettingsPath);
                return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
            }
        }
        catch { /* return defaults on any error */ }
        return new AppSettings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
            var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsPath, json);
        }
        catch { /* best-effort */ }
    }
}
