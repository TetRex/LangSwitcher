using System.Runtime.InteropServices;
using LangSwitcher.Helpers;
using LangSwitcher.Models;

namespace LangSwitcher.UI;

/// <summary>
/// Settings window: enable/disable, auto-switch layout, launch at startup,
/// force-convert hotkey picker, text shortcuts editor, correction counter.
/// </summary>
public sealed class SettingsForm : Form
{
    private readonly AppSettings _settings;

    // Controls we need to reference after construction
    private CheckBox _enabledCheck       = null!;
    private CheckBox _autoSwitchCheck    = null!;
    private CheckBox _launchAtStartCheck = null!;
    private Label    _shortcutLabel      = null!;
    private Label    _correctionLabel    = null!;
    private DataGridView _shortcutsGrid  = null!;

    // Hotkey recording state
    private bool _recording = false;
    private int  _pendingVk = 0;
    private uint _pendingMods = 0;

    public SettingsForm(AppSettings settings)
    {
        _settings = settings;
        BuildUI();
        PopulateValues();
    }

    // ── UI construction ───────────────────────────────────────────────────────

    private void BuildUI()
    {
        Text            = "LangSwitcher Settings";
        Size            = new Size(520, 620);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox     = false;
        StartPosition   = FormStartPosition.CenterScreen;
        BackColor       = Color.FromArgb(18, 18, 18);
        ForeColor       = Color.White;
        Font            = new Font("Segoe UI", 9.5f);

        var panel = new FlowLayoutPanel
        {
            Dock          = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents  = false,
            AutoScroll    = true,
            Padding       = new Padding(20, 16, 20, 16),
        };
        Controls.Add(panel);

        // ── Title ─────────────────────────────────────────────────────────────
        panel.Controls.Add(MakeLabel("LangSwitcher Settings", 15, bold: true));
        panel.Controls.Add(MakeSpacer(8));

        // ── General ───────────────────────────────────────────────────────────
        panel.Controls.Add(MakeSectionHeader("GENERAL"));
        _enabledCheck    = MakeCheckBox("Enable auto-correction");
        _autoSwitchCheck = MakeCheckBox("Auto-switch keyboard layout after correction");
        _launchAtStartCheck = MakeCheckBox("Launch at Windows startup");
        _enabledCheck.CheckedChanged    += (_, _) => { _settings.IsEnabled = _enabledCheck.Checked; _settings.Save(); };
        _autoSwitchCheck.CheckedChanged += (_, _) => { _settings.AutoSwitchLayout = _autoSwitchCheck.Checked; _settings.Save(); };
        _launchAtStartCheck.CheckedChanged += OnLaunchAtStartChanged;
        panel.Controls.Add(_enabledCheck);
        panel.Controls.Add(_autoSwitchCheck);
        panel.Controls.Add(_launchAtStartCheck);
        panel.Controls.Add(MakeSpacer(10));

        // ── Force-convert shortcut ─────────────────────────────────────────────
        panel.Controls.Add(MakeSectionHeader("FORCE-CONVERT SHORTCUT"));
        panel.Controls.Add(MakeLabel("Click the button, then press the key (or key+modifiers).\nNo modifiers = double-tap mode.", 9));
        panel.Controls.Add(MakeSpacer(4));

        var shortcutRow = new FlowLayoutPanel
        {
            AutoSize      = true,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents  = false,
            Margin        = new Padding(0),
        };

        _shortcutLabel = new Label
        {
            AutoSize  = true,
            BackColor = Color.FromArgb(30, 30, 30),
            ForeColor = Color.White,
            Font      = new Font("Cascadia Code", 10f),
            BorderStyle = BorderStyle.FixedSingle,
            Padding   = new Padding(8, 4, 8, 4),
            MinimumSize = new Size(160, 30),
            TextAlign = ContentAlignment.MiddleCenter,
            Margin    = new Padding(0, 0, 8, 0),
        };

        var recordBtn = new Button
        {
            Text      = "Record…",
            AutoSize  = true,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(50, 50, 50),
            ForeColor = Color.White,
            Cursor    = Cursors.Hand,
        };
        recordBtn.Click += OnRecordShortcut;

        shortcutRow.Controls.Add(_shortcutLabel);
        shortcutRow.Controls.Add(recordBtn);
        panel.Controls.Add(shortcutRow);
        panel.Controls.Add(MakeSpacer(12));

        // ── Correction counter ─────────────────────────────────────────────────
        panel.Controls.Add(MakeSectionHeader("STATISTICS"));
        _correctionLabel = MakeLabel("", 9);
        panel.Controls.Add(_correctionLabel);
        panel.Controls.Add(MakeSpacer(10));

        // ── Text shortcuts ─────────────────────────────────────────────────────
        panel.Controls.Add(MakeSectionHeader("TEXT SHORTCUTS"));
        panel.Controls.Add(MakeLabel("Define trigger words that expand into full phrases.", 9));
        panel.Controls.Add(MakeSpacer(4));

        _shortcutsGrid = new DataGridView
        {
            Width             = 460,
            Height            = 200,
            AllowUserToAddRows = false,
            AllowUserToDeleteRows = false,
            RowHeadersVisible = false,
            BackgroundColor   = Color.FromArgb(25, 25, 25),
            GridColor         = Color.FromArgb(50, 50, 50),
            DefaultCellStyle  = new DataGridViewCellStyle
            {
                BackColor = Color.FromArgb(30, 30, 30),
                ForeColor = Color.White,
                SelectionBackColor = Color.FromArgb(60, 60, 120),
                SelectionForeColor = Color.White,
            },
            ColumnHeadersDefaultCellStyle = new DataGridViewCellStyle
            {
                BackColor = Color.FromArgb(40, 40, 40),
                ForeColor = Color.Silver,
            },
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
            BorderStyle         = BorderStyle.None,
            Margin              = new Padding(0),
        };
        _shortcutsGrid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Trigger", HeaderText = "Shortcut",   FillWeight = 35 });
        _shortcutsGrid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Expansion", HeaderText = "Expands To", FillWeight = 65 });
        _shortcutsGrid.CellEndEdit += OnShortcutCellEdited;
        panel.Controls.Add(_shortcutsGrid);

        var btnRow = new FlowLayoutPanel
        {
            AutoSize      = true,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents  = false,
            Margin        = new Padding(0),
        };

        var addBtn = MakeFlatButton("+ Add");
        var remBtn = MakeFlatButton("− Remove");
        addBtn.Click += (_, _) => AddShortcut();
        remBtn.Click += (_, _) => RemoveSelectedShortcut();
        btnRow.Controls.Add(addBtn);
        btnRow.Controls.Add(remBtn);
        panel.Controls.Add(btnRow);

        // Key preview so we can intercept keys during recording
        KeyPreview = true;
        KeyDown += OnKeyDown;
    }

    // ── Populate from settings ─────────────────────────────────────────────────

    private void PopulateValues()
    {
        _enabledCheck.Checked       = _settings.IsEnabled;
        _autoSwitchCheck.Checked    = _settings.AutoSwitchLayout;
        _launchAtStartCheck.Checked = StartupHelper.IsEnabled();
        _correctionLabel.Text       = $"Total corrections made: {_settings.CorrectionCount}";
        _shortcutLabel.Text         = FormatShortcut(_settings.ForceConvertKey, _settings.ForceConvertModifiers);

        _shortcutsGrid.Rows.Clear();
        foreach (var s in _settings.TextShortcuts)
            _shortcutsGrid.Rows.Add(s.Trigger, s.Expansion);
    }

    // ── Launch at startup ──────────────────────────────────────────────────────

    private void OnLaunchAtStartChanged(object? sender, EventArgs e)
    {
        StartupHelper.SetEnabled(_launchAtStartCheck.Checked);
    }

    // ── Force-convert shortcut recording ──────────────────────────────────────

    private void OnRecordShortcut(object? sender, EventArgs e)
    {
        _recording = true;
        _shortcutLabel.Text = "Press a key…";
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (!_recording) return;

        // Escape cancels
        if (e.KeyCode == Keys.Escape)
        {
            _recording = false;
            _shortcutLabel.Text = FormatShortcut(_settings.ForceConvertKey, _settings.ForceConvertModifiers);
            e.Handled = true;
            return;
        }

        // Ignore standalone modifier presses
        if (e.KeyCode == Keys.ShiftKey || e.KeyCode == Keys.ControlKey ||
            e.KeyCode == Keys.Menu     || e.KeyCode == Keys.LWin || e.KeyCode == Keys.RWin)
            return;

        _recording = false;

        _pendingVk   = (int)e.KeyCode;
        _pendingMods = BuildModifiers(e.Modifiers);

        _settings.ForceConvertKey       = _pendingVk;
        _settings.ForceConvertModifiers = _pendingMods;
        _settings.Save();

        _shortcutLabel.Text = FormatShortcut(_pendingVk, _pendingMods);
        e.Handled = true;
    }

    private static uint BuildModifiers(Keys modifiers)
    {
        uint m = 0;
        if ((modifiers & Keys.Shift)   != 0) m |= 1;
        if ((modifiers & Keys.Control) != 0) m |= 2;
        if ((modifiers & Keys.Alt)     != 0) m |= 4;
        return m;
    }

    private static string FormatShortcut(int vk, uint mods)
    {
        if (vk == 0) return "(none)";
        var parts = new List<string>();
        if ((mods & 2) != 0) parts.Add("Ctrl");
        if ((mods & 4) != 0) parts.Add("Alt");
        if ((mods & 1) != 0) parts.Add("Shift");
        parts.Add(((Keys)vk).ToString());
        string label = string.Join("+", parts);
        return mods == 0 ? $"{label} (×2)" : label;
    }

    // ── Text shortcuts ─────────────────────────────────────────────────────────

    private void AddShortcut()
    {
        _settings.TextShortcuts.Add(new TextShortcut());
        _settings.Save();
        int row = _shortcutsGrid.Rows.Add("", "");
        _shortcutsGrid.CurrentCell = _shortcutsGrid.Rows[row].Cells[0];
        _shortcutsGrid.BeginEdit(true);
    }

    private void RemoveSelectedShortcut()
    {
        int idx = _shortcutsGrid.CurrentRow?.Index ?? -1;
        if (idx < 0 || idx >= _settings.TextShortcuts.Count) return;
        _settings.TextShortcuts.RemoveAt(idx);
        _settings.Save();
        _shortcutsGrid.Rows.RemoveAt(idx);
    }

    private void OnShortcutCellEdited(object? sender, DataGridViewCellEventArgs e)
    {
        int row = e.RowIndex;
        if (row < 0) return;

        string trigger   = _shortcutsGrid.Rows[row].Cells[0].Value?.ToString() ?? "";
        string expansion = _shortcutsGrid.Rows[row].Cells[1].Value?.ToString() ?? "";

        if (row < _settings.TextShortcuts.Count)
        {
            _settings.TextShortcuts[row].Trigger   = trigger;
            _settings.TextShortcuts[row].Expansion = expansion;
        }
        else
        {
            _settings.TextShortcuts.Add(new TextShortcut { Trigger = trigger, Expansion = expansion });
        }
        _settings.Save();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Label MakeLabel(string text, float size, bool bold = false)
    {
        return new Label
        {
            Text      = text,
            AutoSize  = true,
            ForeColor = Color.Silver,
            Font      = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular),
            Margin    = new Padding(0, 0, 0, 2),
        };
    }

    private static Label MakeSectionHeader(string text)
    {
        return new Label
        {
            Text      = text,
            AutoSize  = true,
            ForeColor = Color.FromArgb(120, 120, 120),
            Font      = new Font("Segoe UI", 8f, FontStyle.Bold),
            Margin    = new Padding(0, 6, 0, 4),
        };
    }

    private static Panel MakeSpacer(int height)
    {
        return new Panel { Height = height, Width = 1, Margin = new Padding(0) };
    }

    private static CheckBox MakeCheckBox(string text)
    {
        return new CheckBox
        {
            Text      = text,
            AutoSize  = true,
            ForeColor = Color.White,
            Margin    = new Padding(0, 2, 0, 2),
        };
    }

    private static Button MakeFlatButton(string text)
    {
        return new Button
        {
            Text      = text,
            AutoSize  = true,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(45, 45, 45),
            ForeColor = Color.White,
            Margin    = new Padding(0, 4, 6, 0),
            Cursor    = Cursors.Hand,
        };
    }
}
