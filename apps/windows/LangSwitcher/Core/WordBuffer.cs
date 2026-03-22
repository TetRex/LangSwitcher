namespace LangSwitcher.Core;

/// <summary>
/// Buffers characters as the user types, tracks the current in-progress word.
/// </summary>
public sealed class WordBuffer
{
    private const int MaxWordLength = 80;
    private readonly System.Text.StringBuilder _buf = new(MaxWordLength + 1);

    public string Current => _buf.ToString();
    public int Length => _buf.Length;
    public bool IsEmpty => _buf.Length == 0;

    public void Append(char ch)
    {
        if (_buf.Length >= MaxWordLength)
            _buf.Clear();
        _buf.Append(ch);
    }

    public void RemoveLast()
    {
        if (_buf.Length > 0) _buf.Remove(_buf.Length - 1, 1);
    }

    public void Clear() => _buf.Clear();
}
