namespace LangSwitcher.Helpers;

/// <summary>
/// Appends timestamped lines to %AppData%\LangSwitcher\debug.log.
/// Enabled only when the file already exists (create it to activate logging).
/// </summary>
public static class Logger
{
    private static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "LangSwitcher", "debug.log");

    private static readonly bool _enabled;
    private static readonly object _lock = new();

    static Logger()
    {
        _enabled = File.Exists(LogPath);
    }

    public static void Log(string message)
    {
        if (!_enabled) return;
        try
        {
            lock (_lock)
                File.AppendAllText(LogPath, $"[{DateTime.Now:HH:mm:ss.fff}] {message}\n");
        }
        catch { }
    }
}
