namespace LangSwitcher.Helpers;

/// <summary>
/// Appends timestamped lines to %AppData%\LangSwitcher\debug.log.
/// Always active — the file is created on first write.
/// </summary>
public static class Logger
{
    public static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "LangSwitcher", "debug.log");

    private static readonly object _lock = new();

    public static void Log(string message)
    {
        try
        {
            lock (_lock)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);
                File.AppendAllText(LogPath, $"[{DateTime.Now:HH:mm:ss.fff}] {message}\n");
            }
        }
        catch { }
    }
}
