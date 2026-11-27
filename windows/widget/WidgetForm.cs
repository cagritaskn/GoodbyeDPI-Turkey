// GoodbyeDPI Widget - arayuz.
// Kucuk, sade, yari saydam yuvarlak kare icinde wifi simgesi. Pencere per-pixel alpha
// (layered window) olarak GDI+ ile elle cizilir, standart kontrol kullanilmaz.
//  - Acikken simge yesil, kapaliyken kirmizi.
//  - Wifi'nin en altindaki nokta eylem dugmesidir: acikken uzerine gelince kirmizi
//    carpiya donusur, tiklayinca hizmet durur. Kapaliyken nokta yesile doner, tiklayinca baslar.
//  - Islem surerken yaylar alttan uste sirayla yanar.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.Threading;
using System.Windows.Forms;

static class Theme
{
    public static readonly Color On = Color.FromArgb(48, 209, 88);
    public static readonly Color Off = Color.FromArgb(255, 69, 58);

    public static readonly Color Text = Color.FromArgb(240, 242, 246);
    public static readonly Color Muted = Color.FromArgb(128, 136, 152);
    public static readonly Color MenuBg = Color.FromArgb(26, 29, 38);
    public static readonly Color MenuHover = Color.FromArgb(44, 49, 64);
    public static readonly Color MenuBorder = Color.FromArgb(58, 63, 78);

    public static Color Mix(Color a, Color b, float t)
    {
        t = Math.Max(0f, Math.Min(1f, t));
        return Color.FromArgb(
            (int)(a.A + (b.A - a.A) * t), (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));
    }

    public static Color Alpha(Color c, float a)
    {
        return Color.FromArgb((int)Math.Max(0, Math.Min(255, c.A * a)), c);
    }

    public static Font MakeFont(float px, bool bold)
    {
        string f = bold ? "Segoe UI Semibold" : "Segoe UI";
        return new Font(f, px, FontStyle.Regular, GraphicsUnit.Pixel);
    }

    public static GraphicsPath Rounded(RectangleF r, float radius)
    {
        float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
        GraphicsPath p = new GraphicsPath();
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    // Wifi yaylari: tabandaki nokta (p) merkezli, 225..315 derece arasi uc yay.
    // alphas[0..2] = icten disa yaylarin opakligi.
    public static void DrawWifiArcs(Graphics g, PointF p, float unit, float width, Color color, float[] alphas)
    {
        for (int i = 0; i < 3; i++)
        {
            float r = unit * (i + 1);
            using (Pen pen = new Pen(Alpha(color, alphas[i]), width))
            {
                pen.StartCap = LineCap.Round;
                pen.EndCap = LineCap.Round;
                g.DrawArc(pen, p.X - r, p.Y - r, r * 2, r * 2, 225, 90);
            }
        }
    }
}

class DarkMenuColors : ProfessionalColorTable
{
    public override Color ToolStripDropDownBackground { get { return Theme.MenuBg; } }
    public override Color MenuBorder { get { return Theme.MenuBorder; } }
    public override Color MenuItemBorder { get { return Theme.MenuHover; } }
    public override Color MenuItemSelected { get { return Theme.MenuHover; } }
    public override Color MenuItemSelectedGradientBegin { get { return Theme.MenuHover; } }
    public override Color MenuItemSelectedGradientEnd { get { return Theme.MenuHover; } }
    public override Color ImageMarginGradientBegin { get { return Theme.MenuBg; } }
    public override Color ImageMarginGradientMiddle { get { return Theme.MenuBg; } }
    public override Color ImageMarginGradientEnd { get { return Theme.MenuBg; } }
    public override Color SeparatorDark { get { return Theme.MenuBorder; } }
    public override Color SeparatorLight { get { return Theme.MenuBg; } }
    public override Color CheckBackground { get { return Color.FromArgb(40, 80, 60); } }
    public override Color CheckSelectedBackground { get { return Color.FromArgb(50, 100, 72); } }
    public override Color CheckPressedBackground { get { return Color.FromArgb(50, 100, 72); } }
    public override Color ButtonSelectedBorder { get { return Theme.On; } }
}

class DarkMenuRenderer : ToolStripProfessionalRenderer
{
    public DarkMenuRenderer() : base(new DarkMenuColors()) { RoundedEdges = false; }

    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
    {
        e.TextColor = e.Item.Enabled ? Theme.Text : Theme.Muted;
        base.OnRenderItemText(e);
    }

    protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle r = e.ImageRectangle;
        r.Inflate(1, 1);
        using (GraphicsPath p = Theme.Rounded(r, 4))
        using (SolidBrush b = new SolidBrush(Theme.On))
            g.FillPath(b, p);
        using (Pen pen = new Pen(Color.White, Math.Max(1.6f, r.Width / 9f)))
        {
            pen.StartCap = LineCap.Round;
            pen.EndCap = LineCap.Round;
            pen.LineJoin = LineJoin.Round;
            g.DrawLines(pen, new[]
            {
                new PointF(r.X + r.Width * 0.27f, r.Y + r.Height * 0.52f),
                new PointF(r.X + r.Width * 0.44f, r.Y + r.Height * 0.68f),
                new PointF(r.X + r.Width * 0.74f, r.Y + r.Height * 0.34f)
            });
        }
    }
}

class WidgetForm : Form
{
    // Mantiksal (96 DPI) olculer; S ile olceklenir.
    const float Tile = 52, TileR = 14, Pad = 10;
    const float ArcUnit = 6.5f, ArcWidth = 3.2f, DotR = 2.4f;

    readonly float S;
    readonly NotifyIcon tray = new NotifyIcon();
    readonly ContextMenuStrip menu = new ContextMenuStrip();
    readonly ToolStripMenuItem miToggle, miShow, miTopMost, miAutoStart;
    readonly ToolTip tip = new ToolTip();
    readonly System.Windows.Forms.Timer pollTimer = new System.Windows.Forms.Timer();
    readonly System.Windows.Forms.Timer animTimer = new System.Windows.Forms.Timer();
    readonly Dictionary<string, string> settings;

    DpiState state = DpiState.Busy;
    bool busy, busyStarting, firstPoll = true;
    DateTime? runningSince;
    IntPtr trayHicon = IntPtr.Zero;
    string tipText = "";

    // Animasyon durumlari
    float onT;        // 0 = kirmizi (kapali), 1 = yesil (acik)
    float hoverDot;   // noktanin carpiya / yesile donusumu
    float hoverTile;  // kare uzerine gelince hafif belirginlesme
    float press;      // tiklama geri bildirimi
    float wave;       // islem surerken yaylarin sirayla yanmasi
    bool overDot, overTile;

    public WidgetForm()
    {
        settings = Config.Load();
        using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) S = g.DpiX / 96f;

        Text = "GoodbyeDPI";
        Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        int side = (int)Math.Ceiling((Tile + Pad * 2) * S);
        Size = new Size(side, side);
        TopMost = GetSetting("topmost", "1") == "1";
        Location = InitialLocation();

        menu.Renderer = new DarkMenuRenderer();
        menu.Font = Theme.MakeFont(12.5f * S, false);
        miToggle = new ToolStripMenuItem("Başlat", null, delegate { Toggle(); });
        miToggle.Font = Theme.MakeFont(12.5f * S, true);
        miShow = new ToolStripMenuItem("Widget'ı göster", null, delegate { SetWidgetVisible(!Visible); });
        miTopMost = new ToolStripMenuItem("Her zaman üstte", null, delegate { SetTopMost(!TopMost); });
        miAutoStart = new ToolStripMenuItem("Windows ile başlat", null, delegate { ToggleAutoStart(); });
        menu.Items.Add(miToggle);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(miShow);
        menu.Items.Add(miTopMost);
        menu.Items.Add(miAutoStart);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("Çıkış", null, delegate { ExitApp(); }));
        foreach (ToolStripItem it in menu.Items) it.Padding = new Padding(2, (int)(3 * S), 8, (int)(3 * S));
        menu.Opening += delegate
        {
            miShow.Checked = Visible;
            miTopMost.Checked = TopMost;
            miAutoStart.Checked = AutoStart.IsEnabled();
        };

        tray.ContextMenuStrip = menu;
        tray.Visible = true;
        tray.MouseClick += delegate(object s, MouseEventArgs e) { if (e.Button == MouseButtons.Left) SetWidgetVisible(!Visible); };
        ContextMenuStrip = menu;

        tip.InitialDelay = 500;
        tip.ReshowDelay = 200;

        pollTimer.Interval = 2000;
        pollTimer.Tick += delegate { RefreshState(); };
        animTimer.Interval = 16;
        animTimer.Tick += delegate { Animate(); };

        RefreshState();
        pollTimer.Start();
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= Native.WS_EX_LAYERED | Native.WS_EX_TOOLWINDOW;
            return cp;
        }
    }

    protected override void SetVisibleCore(bool value)
    {
        if (!IsHandleCreated && GetSetting("visible", "1") != "1")
        {
            CreateHandle();
            value = false;
        }
        base.SetVisibleCore(value);
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        Render();
    }

    protected override void OnVisibleChanged(EventArgs e)
    {
        base.OnVisibleChanged(e);
        if (Visible) { Render(); StartAnim(); }
    }

    // ---------- Ayarlar ----------

    string GetSetting(string key, string def)
    {
        string v;
        return settings.TryGetValue(key, out v) ? v : def;
    }

    void SaveSettings()
    {
        settings["x"] = Location.X.ToString(CultureInfo.InvariantCulture);
        settings["y"] = Location.Y.ToString(CultureInfo.InvariantCulture);
        settings["topmost"] = TopMost ? "1" : "0";
        settings["visible"] = Visible ? "1" : "0";
        Config.Save(settings);
    }

    Point InitialLocation()
    {
        int x, y;
        if (int.TryParse(GetSetting("x", ""), out x) && int.TryParse(GetSetting("y", ""), out y))
        {
            Rectangle r = new Rectangle(x, y, Width, Height);
            foreach (Screen s in Screen.AllScreens)
                if (s.WorkingArea.IntersectsWith(r)) return new Point(x, y);
        }
        Rectangle wa = Screen.PrimaryScreen.WorkingArea;
        return new Point(wa.Right - Width - (int)(8 * S), wa.Bottom - Height - (int)(8 * S));
    }

    // ---------- Geometri ----------

    RectangleF TileRect { get { return new RectangleF(Pad * S, (Pad - 2) * S, Tile * S, Tile * S); } }

    // Wifi'nin taban noktasi: simge kare icinde dikey olarak ortalanir.
    PointF DotCenter
    {
        get
        {
            RectangleF t = TileRect;
            float glyphH = (ArcUnit * 3 + ArcWidth / 2 + DotR) * S;
            float top = t.Y + (t.Height - glyphH) / 2 + (ArcWidth / 2) * S;
            return new PointF(t.X + t.Width / 2, top + ArcUnit * 3 * S);
        }
    }

    bool HitDot(Point p)
    {
        PointF c = DotCenter;
        float dx = p.X - c.X, dy = p.Y - c.Y, r = 7 * S;
        return dx * dx + dy * dy <= r * r;
    }

    // ---------- Fare ----------

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        bool d = HitDot(e.Location);
        bool t = TileRect.Contains(e.Location);
        if (d != overDot || t != overTile) StartAnim();
        overDot = d;
        overTile = t;
        Cursor = d && !busy ? Cursors.Hand : Cursors.Default;
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        overDot = false;
        overTile = false;
        StartAnim();
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        if (HitDot(e.Location))
        {
            if (!busy) { press = 1f; Toggle(); }
            return;
        }
        Native.ReleaseCapture();
        Native.SendMessage(Handle, Native.WM_NCLBUTTONDOWN, (IntPtr)Native.HTCAPTION, IntPtr.Zero);
        SaveSettings();
    }

    // ---------- Durum ----------

    bool IsOnLike { get { return busy ? busyStarting : (state == DpiState.Running || state == DpiState.Pending); } }
    bool Working { get { return busy || state == DpiState.Pending; } }

    void RefreshState()
    {
        if (busy) return;
        ApplyState(ServiceOps.Query());
    }

    void ApplyState(DpiState s)
    {
        state = s;
        if (s == DpiState.Running)
        {
            if (runningSince == null) runningSince = ProcessStart();
        }
        else if (s != DpiState.Busy) runningSince = null;

        if (firstPoll)
        {
            onT = IsOnLike ? 1f : 0f;
            firstPoll = false;
        }

        miToggle.Text = IsOnLike ? "Durdur" : "Başlat";
        miToggle.Enabled = !busy;
        UpdateTip();
        UpdateTrayIcon();
        StartAnim();
        Render();
    }

    static DateTime ProcessStart()
    {
        Process[] ps = Process.GetProcessesByName("goodbyedpi");
        try
        {
            foreach (Process p in ps)
            {
                try { return p.StartTime; }
                catch (Exception) { }
            }
        }
        finally { foreach (Process p in ps) p.Dispose(); }
        return DateTime.Now;
    }

    string StatusText()
    {
        if (busy) return busyStarting ? "Başlatılıyor…" : "Durduruluyor…";
        switch (state)
        {
            case DpiState.Running:
                return "Açık · " + Uptime(DateTime.Now - (runningSince ?? DateTime.Now));
            case DpiState.Stopped:
            case DpiState.NotInstalled: return "Kapalı";
            default: return "Bekleniyor…";
        }
    }

    void UpdateTip()
    {
        string t = "GoodbyeDPI: " + StatusText();
        if (!busy) t += IsOnLike ? "\nKapatmak için noktaya tıklayın" : "\nAçmak için noktaya tıklayın";
        if (t != tipText)
        {
            tipText = t;
            tip.SetToolTip(this, t);
        }
    }

    static string Uptime(TimeSpan t)
    {
        if (t.TotalMinutes < 1) return "az önce başladı";
        if (t.TotalHours < 1) return (int)t.TotalMinutes + " dk";
        if (t.TotalDays < 1) return (int)t.TotalHours + " sa " + t.Minutes + " dk";
        return (int)t.TotalDays + " gün " + t.Hours + " sa";
    }

    // ---------- Animasyon ----------

    void StartAnim()
    {
        if (!animTimer.Enabled) animTimer.Start();
    }

    static float Approach(float v, float target, float k)
    {
        float d = target - v;
        return Math.Abs(d) < 0.002f ? target : v + d * k;
    }

    void Animate()
    {
        onT = Approach(onT, IsOnLike ? 1f : 0f, 0.12f);
        hoverDot = Approach(hoverDot, overDot && !busy ? 1f : 0f, 0.22f);
        hoverTile = Approach(hoverTile, overTile ? 1f : 0f, 0.18f);
        press = Approach(press, 0f, 0.15f);
        if (Working) wave += 0.09f;

        if (Visible) Render();

        bool settled = !Working
            && onT == (IsOnLike ? 1f : 0f)
            && (hoverDot == 0f || hoverDot == 1f)
            && (hoverTile == 0f || hoverTile == 1f)
            && press == 0f;
        if (settled || !Visible) animTimer.Stop();
    }

    // ---------- Cizim ----------

    void Render()
    {
        if (!IsHandleCreated || Width <= 0 || Height <= 0) return;
        using (Bitmap bmp = new Bitmap(Width, Height, PixelFormat.Format32bppArgb))
        {
            using (Graphics g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.Clear(Color.Transparent);

                // Tiklamada hafif "basilma" kuculmesi
                float scale = 1f - 0.05f * press;
                RectangleF t = TileRect;
                PointF mid = new PointF(t.X + t.Width / 2, t.Y + t.Height / 2);
                g.TranslateTransform(mid.X, mid.Y);
                g.ScaleTransform(scale, scale);
                g.TranslateTransform(-mid.X, -mid.Y);

                DrawGlass(g);
                DrawWifi(g);
            }
            Present(bmp);
        }
    }

    void Present(Bitmap bmp)
    {
        IntPtr screenDc = Native.GetDC(IntPtr.Zero);
        IntPtr memDc = Native.CreateCompatibleDC(screenDc);
        IntPtr hBmp = bmp.GetHbitmap(Color.FromArgb(0));
        IntPtr old = Native.SelectObject(memDc, hBmp);
        try
        {
            Native.SIZE size = new Native.SIZE { CX = bmp.Width, CY = bmp.Height };
            Native.POINT src = new Native.POINT();
            Native.BLENDFUNCTION blend = new Native.BLENDFUNCTION
            {
                BlendOp = 0, BlendFlags = 0, SourceConstantAlpha = 255, AlphaFormat = Native.AC_SRC_ALPHA
            };
            Native.UpdateLayeredWindow(Handle, screenDc, IntPtr.Zero, ref size, memDc, ref src, 0, ref blend, Native.ULW_ALPHA);
        }
        finally
        {
            Native.SelectObject(memDc, old);
            Native.DeleteObject(hBmp);
            Native.DeleteDC(memDc);
            Native.ReleaseDC(IntPtr.Zero, screenDc);
        }
    }

    Color Accent { get { return Theme.Mix(Theme.Off, Theme.On, onT); } }

    // Sade, yari saydam yuvarlak kare: duz govde, ince kenar, hafif golge.
    void DrawGlass(Graphics g)
    {
        RectangleF t = TileRect;
        float rad = TileR * S;

        int layers = (int)(6 * S);
        for (int i = layers; i >= 1; i--)
        {
            RectangleF r = t;
            r.Inflate(i, i);
            r.Offset(0, 2 * S);
            using (GraphicsPath p = Theme.Rounded(r, rad + i))
            using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(8f * (layers - i + 1) / layers), 0, 0, 0)))
                g.FillPath(b, p);
        }

        using (GraphicsPath glass = Theme.Rounded(t, rad))
        {
            using (SolidBrush body = new SolidBrush(Color.FromArgb((int)(130 + 25 * hoverTile), 28, 30, 38)))
                g.FillPath(body, glass);

            RectangleF br = t;
            br.Inflate(-0.5f * S, -0.5f * S);
            using (GraphicsPath bp = Theme.Rounded(br, rad))
            using (Pen pen = new Pen(Color.FromArgb((int)(45 + 25 * hoverTile), 255, 255, 255), Math.Max(1f, S)))
                g.DrawPath(pen, bp);
        }
    }

    void DrawWifi(Graphics g)
    {
        PointF p = DotCenter;
        Color accent = Accent;

        // Islem surerken: yaylar alttan uste sirayla yanip soner.
        float[] alphas = { 1f, 1f, 1f };
        float dotAlpha = 1f;
        if (Working)
        {
            dotAlpha = Wave(0);
            for (int i = 0; i < 3; i++) alphas[i] = Wave(i + 1);
        }

        Theme.DrawWifiArcs(g, p, ArcUnit * S, ArcWidth * S, accent, alphas);
        DrawDot(g, p, accent, dotAlpha);
    }

    float Wave(int i)
    {
        double v = Math.Sin(wave - i * 0.85);
        return 0.25f + 0.75f * (float)Math.Max(0, v);
    }

    // Taban noktasi. Acikken hover: nokta kuculup kaybolur, yerine kirmizi carpi buyur.
    // Kapaliyken hover: nokta yesile doner ve hafifce buyur. Yaylar degismez.
    void DrawDot(Graphics g, PointF p, Color accent, float alpha)
    {
        float h = hoverDot;
        bool on = IsOnLike;

        if (on)
        {
            float dr = DotR * S * (1f - h);
            if (dr > 0.2f)
                using (SolidBrush b = new SolidBrush(Theme.Alpha(accent, alpha)))
                    g.FillEllipse(b, p.X - dr, p.Y - dr, dr * 2, dr * 2);

            if (h > 0.01f)
            {
                float x = 2.5f * S * h;
                using (Pen pen = new Pen(Color.FromArgb((int)(255 * h), Theme.Off), 2f * S))
                {
                    pen.StartCap = LineCap.Round;
                    pen.EndCap = LineCap.Round;
                    g.DrawLine(pen, p.X - x, p.Y - x, p.X + x, p.Y + x);
                    g.DrawLine(pen, p.X + x, p.Y - x, p.X - x, p.Y + x);
                }
            }
        }
        else
        {
            Color c = Theme.Mix(accent, Theme.On, h);
            float dr = DotR * S * (1f + 0.3f * h);
            using (SolidBrush b = new SolidBrush(Theme.Alpha(c, alpha)))
                g.FillEllipse(b, p.X - dr, p.Y - dr, dr * 2, dr * 2);
        }
    }

    // Tepsi ikonu: wifi simgesi w x w ikona orantili sigdirilir ve ortalanir.
    // En distaki yayin genisligi 2 * 3u * sin45 + kalinlik oldugundan yay araligi (u) buna gore secilir.
    static void DrawTrayGlyph(Graphics g, float w, Color c)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        float stroke = Math.Max(1.5f, w * 0.12f);
        float dot = Math.Max(1.1f, w * 0.085f);
        float unit = (w * 0.92f - stroke) / (3f * 1.4142f);
        float glyphH = unit * 3 + stroke / 2 + dot;
        PointF p = new PointF(w / 2, (w - glyphH) / 2 + unit * 3 + stroke / 2);
        Theme.DrawWifiArcs(g, p, unit, stroke, c, new[] { 1f, 1f, 1f });
        using (SolidBrush b = new SolidBrush(c))
            g.FillEllipse(b, p.X - dot, p.Y - dot, dot * 2, dot * 2);
    }

    void UpdateTrayIcon()
    {
        Size sz = SystemInformation.SmallIconSize;
        using (Bitmap bmp = new Bitmap(sz.Width, sz.Height, PixelFormat.Format32bppArgb))
        {
            using (Graphics g = Graphics.FromImage(bmp))
            {
                Color c = busy ? Color.FromArgb(255, 200, 40) : (IsOnLike ? Theme.On : Theme.Off);
                DrawTrayGlyph(g, sz.Width, c);
            }
            IntPtr h = bmp.GetHicon();
            tray.Icon = System.Drawing.Icon.FromHandle(h);
            if (trayHicon != IntPtr.Zero) Native.DestroyIcon(trayHicon);
            trayHicon = h;
        }
        tray.Text = "GoodbyeDPI: " + StatusText();
    }

    // ---------- Eylemler ----------

    void Toggle()
    {
        if (busy) return;
        bool starting = !IsOnLike;

        busy = true;
        busyStarting = starting;
        wave = 0f;
        ApplyState(DpiState.Busy);

        Thread t = new Thread(delegate()
        {
            string error = null;
            try
            {
                if (starting) ServiceOps.Start();
                else ServiceOps.Stop();
            }
            catch (Exception ex)
            {
                error = ex.Message;
            }
            DpiState result = ServiceOps.Query();

            BeginInvoke((MethodInvoker)delegate
            {
                busy = false;
                ApplyState(result);
                if (error != null)
                    tray.ShowBalloonTip(5000, "GoodbyeDPI", error, ToolTipIcon.Error);
            });
        });
        t.IsBackground = true;
        t.Start();
    }

    void SetWidgetVisible(bool v)
    {
        if (v) { Show(); Activate(); } else Hide();
        SaveSettings();
    }

    void SetTopMost(bool v)
    {
        TopMost = v;
        SaveSettings();
    }

    void ToggleAutoStart()
    {
        bool ok = AutoStart.IsEnabled() ? AutoStart.Disable() : AutoStart.Enable();
        if (!ok) tray.ShowBalloonTip(4000, "GoodbyeDPI", "Başlangıç ayarı değiştirilemedi.", ToolTipIcon.Error);
    }

    void ExitApp()
    {
        SaveSettings();
        pollTimer.Stop();
        animTimer.Stop();
        tray.Visible = false;
        tray.Dispose();
        if (trayHicon != IntPtr.Zero) Native.DestroyIcon(trayHicon);
        Application.Exit();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            SetWidgetVisible(false);
            return;
        }
        base.OnFormClosing(e);
    }
}
