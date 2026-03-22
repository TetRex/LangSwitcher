using LangSwitcher.Helpers;

namespace LangSwitcher.UI;

/// <summary>
/// Small floating window that displays live log output from Logger.
/// </summary>
public sealed class DebugWindow : Form
{
    private readonly RichTextBox _box;
    private readonly Button _clearBtn;
    private const int MaxLines = 500;

    public DebugWindow()
    {
        Text            = "LangSwitcher — Debug";
        Size            = new Size(600, 400);
        MinimumSize     = new Size(400, 200);
        StartPosition   = FormStartPosition.Manual;
        Location        = new Point(
            Screen.PrimaryScreen!.WorkingArea.Right - Width - 16,
            Screen.PrimaryScreen!.WorkingArea.Bottom - Height - 16);
        TopMost         = true;
        BackColor       = Color.FromArgb(12, 12, 12);
        ForeColor       = Color.FromArgb(200, 200, 200);
        Font            = new Font("Cascadia Code", 9f);
        FormBorderStyle = FormBorderStyle.SizableToolWindow;

        _box = new RichTextBox
        {
            Dock            = DockStyle.Fill,
            BackColor       = Color.FromArgb(12, 12, 12),
            ForeColor       = Color.FromArgb(200, 200, 200),
            Font            = new Font("Cascadia Code", 9f),
            ReadOnly        = true,
            BorderStyle     = BorderStyle.None,
            ScrollBars      = RichTextBoxScrollBars.Vertical,
            WordWrap        = false,
            DetectUrls      = false,
        };

        _clearBtn = new Button
        {
            Text      = "Clear",
            Dock      = DockStyle.Bottom,
            Height    = 26,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(30, 30, 30),
            ForeColor = Color.Silver,
            Cursor    = Cursors.Hand,
        };
        _clearBtn.FlatAppearance.BorderColor = Color.FromArgb(50, 50, 50);
        _clearBtn.Click += (_, _) => _box.Clear();

        Controls.Add(_box);
        Controls.Add(_clearBtn);

        // Replay lines logged before this window was opened
        foreach (var line in Logger.GetBufferedLines())
            OnLine(line);

        Logger.LineLogged += OnLine;
        FormClosed += (_, _) => Logger.LineLogged -= OnLine;
    }

    private void OnLine(string line)
    {
        if (IsDisposed) return;

        // Marshal to UI thread — Logger fires from hook callback (main thread), but be safe.
        if (InvokeRequired) { BeginInvoke(() => OnLine(line)); return; }

        // Colour-code by content
        Color color = line.Contains("WORD:")           ? Color.FromArgb(100, 200, 255)
                    : line.Contains("→")               ? Color.FromArgb(100, 255, 140)
                    : line.Contains("FAILED")
                   || line.Contains("threw")
                   || line.Contains("null")            ? Color.FromArgb(255, 120, 100)
                    : line.Contains("self-test")
                   || line.Contains("SpellChecker")    ? Color.FromArgb(255, 210, 100)
                    : Color.FromArgb(180, 180, 180);

        _box.SuspendLayout();

        // Trim old lines to keep memory bounded
        if (_box.Lines.Length > MaxLines)
            _box.Select(0, _box.GetFirstCharIndexFromLine(MaxLines / 2));

        int start = _box.TextLength;
        _box.AppendText(line + "\n");
        _box.Select(start, line.Length);
        _box.SelectionColor = color;

        // Auto-scroll only when already at the bottom
        _box.Select(_box.TextLength, 0);
        _box.ScrollToCaret();
        _box.ResumeLayout();
    }
}
