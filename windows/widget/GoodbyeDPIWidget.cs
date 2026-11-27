// GoodbyeDPI Widget
// Masaustunde kucuk bir pencere ve sistem tepsisinde ikon olarak calisir.
// GoodbyeDPI hizmetini Windows servis API'si ile dogrudan yonetir:
//  - Ac:    hizmet yoksa kurulur, varsa yolu/parametreleri guncellenir; baslatma turu
//           "otomatik" yapilir ve hizmet baslatilir. Bilgisayar yeniden baslayinca da acilir.
//  - Kapat: hizmet durdurulur ve baslatma turu "elle" yapilir. Yeniden baslayinca kapali kalir.
// goodbyedpi.exe parametreleri service_install_dnsredir_turkey.cmd icindeki "sc create"
// satirindan okunur; DNS/TTL ayarlari tek yerde (o scriptte) durur.

using System;
using System.Collections.Generic;
using System.ComponentModel;
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
using System.Text.RegularExpressions;
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
    public const string ParamsScript = "service_install_dnsredir_turkey.cmd";
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

    // ---------- Win32 servis API ----------

    const uint SC_MANAGER_ALL_ACCESS = 0xF003F;
    const uint SERVICE_ALL_ACCESS = 0xF01FF;
    const uint SERVICE_WIN32_OWN_PROCESS = 0x10;
    const uint SERVICE_AUTO_START = 2;
    const uint SERVICE_DEMAND_START = 3;
    const uint SERVICE_ERROR_NORMAL = 1;
    const uint SERVICE_NO_CHANGE = 0xFFFFFFFF;
    const int SERVICE_CONFIG_DESCRIPTION = 1;
    const int ERROR_SERVICE_DOES_NOT_EXIST = 1060;
    const int ERROR_SERVICE_MARKED_FOR_DELETE = 1072;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct SERVICE_DESCRIPTION { [MarshalAs(UnmanagedType.LPWStr)] public string lpDescription; }

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr OpenSCManager(string machine, string database, uint access);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr OpenService(IntPtr scm, string name, uint access);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateService(IntPtr scm, string name, string displayName, uint access, uint serviceType,
        uint startType, uint errorControl, string binaryPath, string loadOrderGroup, IntPtr tagId,
        string dependencies, string startName, string password);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool ChangeServiceConfig(IntPtr service, uint serviceType, uint startType, uint errorControl,
        string binaryPath, string loadOrderGroup, IntPtr tagId, string dependencies, string startName,
        string password, string displayName);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool ChangeServiceConfig2(IntPtr service, int infoLevel, ref SERVICE_DESCRIPTION info);
    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool CloseServiceHandle(IntPtr handle);

    static Exception Win32Error(string what)
    {
        int code = Marshal.GetLastWin32Error();
        if (code == ERROR_SERVICE_MARKED_FOR_DELETE)
            return new InvalidOperationException(what + ": hizmet silinmek üzere işaretli. Hizmetler penceresi açıksa kapatıp tekrar deneyin.");
        return new InvalidOperationException(what + ": " + new Win32Exception(code).Message);
    }

    // ---------- Ac / kapat ----------

    // service_install_dnsredir_turkey.cmd ile ayni mimari secimi.
    static string Arch
    {
        get
        {
            string a = Environment.GetEnvironmentVariable("PROCESSOR_ARCHITECTURE");
            bool x64 = string.Equals(a, "AMD64", StringComparison.OrdinalIgnoreCase)
                || Environment.GetEnvironmentVariable("PROCESSOR_ARCHITEW6432") != null;
            return x64 ? "x86_64" : "x86";
        }
    }

    // Parametre scriptindeki "sc create" ve "sc description" satirlarini okur.
    static void ReadScript(out string args, out string description)
    {
        string path = Path.Combine(Config.AppDir, Config.ParamsScript);
        if (!File.Exists(path))
            throw new FileNotFoundException(Config.ParamsScript + " bulunamadı. Widget, bu script ile aynı klasörde olmalı.", path);
        string text = File.ReadAllText(path);

        Match m = Regex.Match(text, @"binPath=\s*""\\""%CD%\\%_arch%\\goodbyedpi\.exe\\""\s*(?<args>[^""]*)""", RegexOptions.IgnoreCase);
        if (!m.Success)
            throw new InvalidOperationException(Config.ParamsScript + " içindeki \"sc create\" satırı okunamadı.");
        args = m.Groups["args"].Value.Trim();

        Match d = Regex.Match(text, @"sc\s+description\s+""GoodbyeDPI""\s+""(?<d>[^""]*)""", RegexOptions.IgnoreCase);
        description = d.Success ? d.Groups["d"].Value : null;
    }

    public static void Start()
    {
        string exe = Path.Combine(Config.AppDir, Arch + "\\goodbyedpi.exe");
        if (!File.Exists(exe))
            throw new FileNotFoundException(Arch + "\\goodbyedpi.exe bulunamadı. Release zip'indeki " + Arch +
                " klasörünü widget ile aynı klasöre kopyalayın.", exe);

        string args, description;
        ReadScript(out args, out description);
        string binPath = "\"" + exe + "\"" + (args.Length > 0 ? " " + args : "");

        IntPtr scm = OpenSCManager(null, null, SC_MANAGER_ALL_ACCESS);
        if (scm == IntPtr.Zero) throw Win32Error("Hizmet yöneticisi açılamadı");
        try
        {
            IntPtr svc = OpenService(scm, Config.ServiceName, SERVICE_ALL_ACCESS);
            if (svc == IntPtr.Zero)
            {
                if (Marshal.GetLastWin32Error() != ERROR_SERVICE_DOES_NOT_EXIST) throw Win32Error("Hizmet açılamadı");
                svc = CreateService(scm, Config.ServiceName, Config.ServiceName, SERVICE_ALL_ACCESS,
                    SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL, binPath,
                    null, IntPtr.Zero, null, null, null);
                if (svc == IntPtr.Zero) throw Win32Error("Hizmet kurulamadı");
            }
            else if (!ChangeServiceConfig(svc, SERVICE_NO_CHANGE, SERVICE_AUTO_START, SERVICE_NO_CHANGE, binPath,
                         null, IntPtr.Zero, null, null, null, null))
            {
                CloseServiceHandle(svc);
                throw Win32Error("Hizmet ayarlanamadı");
            }

            if (description != null)
            {
                SERVICE_DESCRIPTION sd = new SERVICE_DESCRIPTION { lpDescription = description };
                ChangeServiceConfig2(svc, SERVICE_CONFIG_DESCRIPTION, ref sd);
            }
            CloseServiceHandle(svc);
        }
        finally { CloseServiceHandle(scm); }

        using (ServiceController sc = new ServiceController(Config.ServiceName))
        {
            if (sc.Status == ServiceControllerStatus.StopPending)
                sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(15));
            if (sc.Status == ServiceControllerStatus.Stopped)
            {
                try { sc.Start(); }
                catch (InvalidOperationException ex)
                {
                    throw new InvalidOperationException("Hizmet başlatılamadı: " +
                        (ex.InnerException != null ? ex.InnerException.Message : ex.Message));
                }
            }
            sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(15));
        }

        // goodbyedpi.exe acilir acilmaz kapanirsa (ornegin WinDivert yuklenemezse) bunu yakala.
        Thread.Sleep(1500);
        if (Query() != DpiState.Running)
            throw new InvalidOperationException("Hizmet başladı ama hemen durdu. Olay Görüntüleyicisi'nde GoodbyeDPI kayıtlarına bakın.");
    }

    public static void Stop()
    {
        IntPtr scm = OpenSCManager(null, null, SC_MANAGER_ALL_ACCESS);
        if (scm == IntPtr.Zero) throw Win32Error("Hizmet yöneticisi açılamadı");
        try
        {
            IntPtr svc = OpenService(scm, Config.ServiceName, SERVICE_ALL_ACCESS);
            if (svc == IntPtr.Zero)
            {
                if (Marshal.GetLastWin32Error() == ERROR_SERVICE_DOES_NOT_EXIST) return;
                throw Win32Error("Hizmet açılamadı");
            }
            bool ok = ChangeServiceConfig(svc, SERVICE_NO_CHANGE, SERVICE_DEMAND_START, SERVICE_NO_CHANGE,
                null, null, IntPtr.Zero, null, null, null, null);
            if (!ok)
            {
                Exception err = Win32Error("Hizmet ayarlanamadı");
                CloseServiceHandle(svc);
                throw err;
            }
            CloseServiceHandle(svc);
        }
        finally { CloseServiceHandle(scm); }

        using (ServiceController sc = new ServiceController(Config.ServiceName))
        {
            if (sc.Status == ServiceControllerStatus.StartPending)
                sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(15));
            if (sc.Status != ServiceControllerStatus.Stopped && sc.Status != ServiceControllerStatus.StopPending)
                sc.Stop();
            sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(15));
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

