// GoodbyeDPI Widget
// Masaustunde kucuk bir pencere ve sistem tepsisinde ikon olarak calisir.
// Baslat: service_install_dnsredir_turkey.cmd
// Durdur: service_remove.cmd
// Scriptler bu exe ile ayni klasorde bulunmalidir.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Threading;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static void Main()
    {
        bool created;
        using (Mutex mutex = new Mutex(true, "Local\\GoodbyeDPIWidget", out created))
        {
            if (!created) return;
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new WidgetForm());
        }
    }
}

enum DpiState { Running, Stopped, Pending, NotInstalled, Busy }

static class Native
{
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct SIZE { public int CX, CY; }
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct BLENDFUNCTION { public byte BlendOp, BlendFlags, SourceConstantAlpha, AlphaFormat; }

    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr hIcon);
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("user32.dll")]
    public static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, IntPtr pptDst, ref SIZE psize,
        IntPtr hdcSrc, ref POINT pptSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
    [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr hDC);
    [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hdc);
    [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr hObject);

    public const int WM_NCLBUTTONDOWN = 0xA1;
    public const int HTCAPTION = 2;
    public const int WS_EX_TOOLWINDOW = 0x80;
    public const int WS_EX_LAYERED = 0x80000;
    public const int ULW_ALPHA = 2;
    public const byte AC_SRC_ALPHA = 1;
}

static class Config
{
    public const string ServiceName = "GoodbyeDPI";
    public const string StartScript = "service_install_dnsredir_turkey.cmd";
    public const string StopScript = "service_remove.cmd";
    public const string TaskName = "GoodbyeDPI Widget";

    public static string AppDir { get { return Path.GetDirectoryName(Application.ExecutablePath); } }

    static string SettingsPath
    {
        get
        {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "GoodbyeDPI-Widget");
            Directory.CreateDirectory(dir);
            return Path.Combine(dir, "widget.ini");
        }
    }

    public static Dictionary<string, string> Load()
    {
        Dictionary<string, string> d = new Dictionary<string, string>();
        try
        {
            if (!File.Exists(SettingsPath)) return d;
            foreach (string line in File.ReadAllLines(SettingsPath))
            {
                int i = line.IndexOf('=');
                if (i > 0) d[line.Substring(0, i).Trim()] = line.Substring(i + 1).Trim();
            }
        }
        catch (IOException) { }
        return d;
    }

    public static void Save(Dictionary<string, string> d)
    {
        StringBuilder sb = new StringBuilder();
        foreach (KeyValuePair<string, string> kv in d) sb.AppendLine(kv.Key + "=" + kv.Value);
        try { File.WriteAllText(SettingsPath, sb.ToString()); }
        catch (IOException) { }
    }
}

static class ServiceOps
{
    public static DpiState Query()
    {
        try
        {
            using (ServiceController sc = new ServiceController(Config.ServiceName))
            {
                ServiceControllerStatus s = sc.Status;
                if (s == ServiceControllerStatus.Running) return DpiState.Running;
                if (s == ServiceControllerStatus.Stopped) return DpiState.Stopped;
                return DpiState.Pending;
            }
        }
        catch (InvalidOperationException)
        {
            return DpiState.NotInstalled;
        }
    }

    // Scripti gizli bir cmd ile calistirir. stdin hemen kapatildigi icin "pause" beklemeden gecer.
    public static string RunScript(string scriptName)
    {
        string path = Path.Combine(Config.AppDir, scriptName);
        if (!File.Exists(path))
            throw new FileNotFoundException(scriptName + " bulunamadi. Widget exe'si scriptlerle ayni klasorde olmali.", path);

        Encoding oem = Encoding.GetEncoding(CultureInfo.CurrentCulture.TextInfo.OEMCodePage);
        ProcessStartInfo psi = new ProcessStartInfo("cmd.exe", "/d /c \"\"" + path + "\"\"");
        psi.WorkingDirectory = Config.AppDir;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardInput = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.StandardOutputEncoding = oem;
        psi.StandardErrorEncoding = oem;

        StringBuilder err = new StringBuilder();
        using (Process p = Process.Start(psi))
        {
            p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) { if (e.Data != null) lock (err) err.AppendLine(e.Data); };
            p.BeginErrorReadLine();
            p.StandardInput.Close();
            string output = p.StandardOutput.ReadToEnd();
            p.WaitForExit();
            lock (err) return output + err.ToString();
        }
    }
}

static class AutoStart
{
    static int Schtasks(string args)
    {
        ProcessStartInfo psi = new ProcessStartInfo("schtasks.exe", args);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        using (Process p = Process.Start(psi))
        {
            p.StandardOutput.ReadToEnd();
            p.StandardError.ReadToEnd();
            p.WaitForExit();
            return p.ExitCode;
        }
    }

    public static bool IsEnabled()
    {
        return Schtasks("/Query /TN \"" + Config.TaskName + "\"") == 0;
    }

    // Yonetici yetkisiyle oturum acilisinda calisan zamanlanmis gorev: her acilista UAC sormaz.
    public static bool Enable()
    {
        string user = SecurityElement.Escape(WindowsIdentity.GetCurrent().Name);
        string exe = SecurityElement.Escape(Application.ExecutablePath);
        string dir = SecurityElement.Escape(Config.AppDir);
        string xml =
            "<?xml version=\"1.0\" encoding=\"UTF-16\"?>\r\n" +
            "<Task version=\"1.2\" xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">\r\n" +
            "  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>" + user + "</UserId></LogonTrigger></Triggers>\r\n" +
            "  <Principals><Principal id=\"Author\"><UserId>" + user + "</UserId><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>\r\n" +
            "  <Settings>\r\n" +
            "    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>\r\n" +
            "    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>\r\n" +
            "    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>\r\n" +
            "    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>\r\n" +
            "    <Priority>7</Priority>\r\n" +
            "  </Settings>\r\n" +
            "  <Actions Context=\"Author\"><Exec><Command>" + exe + "</Command><WorkingDirectory>" + dir + "</WorkingDirectory></Exec></Actions>\r\n" +
            "</Task>\r\n";
        string tmp = Path.Combine(Path.GetTempPath(), "goodbyedpi-widget-task.xml");
        File.WriteAllText(tmp, xml, Encoding.Unicode);
        try { return Schtasks("/Create /TN \"" + Config.TaskName + "\" /XML \"" + tmp + "\" /F") == 0; }
        finally { File.Delete(tmp); }
    }

    public static bool Disable()
    {
        return Schtasks("/Delete /TN \"" + Config.TaskName + "\" /F") == 0;
    }
}

