namespace LangSwitcher.Helpers;

public static class Logger
{
    /// Fired on every log line (on the calling thread).
    public static event Action<string>? LineLogged;

    // Ring buffer — stores the last 300 lines so DebugWindow can replay them on open.
    private static readonly Queue<string> _buffer = new();
    private const int MaxBuffer = 300;
    private static readonly object _lock = new();

    public static string[] GetBufferedLines()
    {
        lock (_lock) return _buffer.ToArray();
    }

    public static void Log(string message)
    {
        var line = $"[{DateTime.Now:HH:mm:ss.fff}] {message}";
        lock (_lock)
        {
            _buffer.Enqueue(line);
            if (_buffer.Count > MaxBuffer) _buffer.Dequeue();
        }
        LineLogged?.Invoke(line);
    }
}
