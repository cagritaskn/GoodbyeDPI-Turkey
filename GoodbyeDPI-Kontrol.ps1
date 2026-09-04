param(
    [switch]$InstallOnly
)

# ============================================================================
#  GoodbyeDPI Kontrol / GoodbyeDPI Control
#  Bilingual (TR/EN) on-off control panel + method selector for GoodbyeDPI-Turkey
#  Iki dilli (TR/EN) ac-kapa kontrol paneli + metod secici
#
#  - Auto-elevates to Administrator / Otomatik yonetici yukseltme
#  - Detects x86 / x86_64 automatically / Mimari otomatik algilanir
#  - Installs GoodbyeDPI as a Windows service and toggles it on/off
#  - Method dropdown covers all 7 install variants shipped with the fork
#  - Remembers last method + language in GoodbyeDPI-Kontrol.config.json
#  Works on Windows 7/8/8.1/10/11 (PowerShell 2.0+ with .NET WinForms)
# ============================================================================

$ErrorActionPreference = "Stop"

$ServiceName       = "GoodbyeDPI"
$InstallRoot       = Join-Path $PSScriptRoot "release"
$LogPath           = Join-Path $PSScriptRoot "GoodbyeDPI-Kontrol.log"
$ConfigPath        = Join-Path $PSScriptRoot "GoodbyeDPI-Kontrol.config.json"
$ServiceDescription = "GoodbyeDPI-Turkey - DPI/DNS bypass service."

# ---------------------------------------------------------------------------
#  Architecture detection
# ---------------------------------------------------------------------------
$Arch = "x86"
if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64" -or $env:PROCESSOR_ARCHITEW6432) {
    $Arch = "x86_64"
}

# ---------------------------------------------------------------------------
#  Method table - all 7 variants from the fork's .cmd files
#  Dns = $true  -> method presets Yandex DNS itself (no manual DNS needed)
#  Dns = $false -> user must set Windows DNS manually
# ---------------------------------------------------------------------------
$Methods = @(
    [pscustomobject]@{
        Key = "main"
        Args = "-5 --set-ttl 5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253"
        Dns = $true
        Tr = "Onerilen - Ana metod (Yandex DNS + TTL 5)"
        En = "Recommended - Main method (Yandex DNS + TTL 5)"
    },
    [pscustomobject]@{
        Key = "alt4"
        Args = "-5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253"
        Dns = $true
        Tr = "SuperOnline Alt 4 (-5, Yandex DNS, TTL yok)"
        En = "SuperOnline Alt 4 (-5, Yandex DNS, no TTL)"
    },
    [pscustomobject]@{
        Key = "alt3"
        Args = "--set-ttl 3 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253"
        Dns = $true
        Tr = "SuperOnline Alt 3 (TTL 3 + Yandex DNS)"
        En = "SuperOnline Alt 3 (TTL 3 + Yandex DNS)"
    },
    [pscustomobject]@{
        Key = "alt5"
        Args = "-9 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253"
        Dns = $true
        Tr = "SuperOnline Alt 5 (-9 + Yandex DNS)"
        En = "SuperOnline Alt 5 (-9 + Yandex DNS)"
    },
    [pscustomobject]@{
        Key = "alt1"
        Args = "--set-ttl 3"
        Dns = $false
        Tr = "SuperOnline Alt 1 (TTL 3, DNS'i elle ayarla)"
        En = "SuperOnline Alt 1 (TTL 3, set DNS manually)"
    },
    [pscustomobject]@{
        Key = "alt2"
        Args = "-5"
        Dns = $false
        Tr = "SuperOnline Alt 2 (-5, DNS'i elle ayarla)"
        En = "SuperOnline Alt 2 (-5, set DNS manually)"
    },
    [pscustomobject]@{
        Key = "alt6"
        Args = "-9"
        Dns = $false
        Tr = "SuperOnline Alt 6 (-9, DNS'i elle ayarla)"
        En = "SuperOnline Alt 6 (-9, set DNS manually)"
    }
)

# ---------------------------------------------------------------------------
#  Localization strings
# ---------------------------------------------------------------------------
$Strings = @{
    tr = @{
        Title          = "GoodbyeDPI Kontrol"
        Method         = "Metod:"
        StatusRunning  = "Durum: calisiyor"
        StatusStopped  = "Durum: kapali"
        StatusNotInst  = "Durum: servis kurulu degil"
        BtnTurnOff     = "GoodbyeDPI'i kapat"
        BtnTurnOn      = "GoodbyeDPI'i ac"
        BtnInstallOn   = "Kur ve ac"
        BtnReinstall   = "Servisi yeniden kur"
        BtnRemove      = "Servisi kaldir"
        BtnLang        = "EN"
        NoteManualDns  = "! Bu metod DNS ayarlamaz. Windows DNS'ini elle Yandex (77.88.8.8) yapmalisin."
        NotePresetDns  = "Bu metod DNS'i otomatik ayarlar. Elle DNS degistirmene gerek yok."
        ExeMissing     = "goodbyedpi.exe bulunamadi. release klasoru eksik olabilir:`n{0}"
        ApplyRunning   = "Metod degisti. Yeni metodu uygulamak icin servis yeniden kuruluyor..."
        ErrTitle       = "GoodbyeDPI Kontrol"
    }
    en = @{
        Title          = "GoodbyeDPI Control"
        Method         = "Method:"
        StatusRunning  = "Status: running"
        StatusStopped  = "Status: stopped"
        StatusNotInst  = "Status: service not installed"
        BtnTurnOff     = "Turn GoodbyeDPI off"
        BtnTurnOn      = "Turn GoodbyeDPI on"
        BtnInstallOn   = "Install and start"
        BtnReinstall   = "Reinstall service"
        BtnRemove      = "Remove service"
        BtnLang        = "TR"
        NoteManualDns  = "! This method does not set DNS. Set your Windows DNS to Yandex (77.88.8.8) manually."
        NotePresetDns  = "This method sets DNS automatically. No manual DNS change needed."
        ExeMissing     = "goodbyedpi.exe not found. The release folder may be missing:`n{0}"
        ApplyRunning   = "Method changed. Reinstalling the service to apply the new method..."
        ErrTitle       = "GoodbyeDPI Control"
    }
}

# ---------------------------------------------------------------------------
#  Config load / save
# ---------------------------------------------------------------------------
function Get-DefaultLang {
    try {
        if ((Get-Culture).TwoLetterISOLanguageName -eq "tr") { return "tr" }
    } catch { }
    return "en"
}

function Load-Config {
    $cfg = @{ method = $Methods[0].Key; lang = (Get-DefaultLang) }
    if (Test-Path $ConfigPath) {
        try {
            $raw = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($raw.method) { $cfg.method = [string]$raw.method }
            if ($raw.lang)   { $cfg.lang   = [string]$raw.lang }
        } catch { }
    }
    if ($cfg.lang -ne "tr" -and $cfg.lang -ne "en") { $cfg.lang = (Get-DefaultLang) }
    if (-not ($Methods.Key -contains $cfg.method)) { $cfg.method = $Methods[0].Key }
    return $cfg
}

function Save-Config {
    param([string]$Method, [string]$Lang)
    try {
        [pscustomobject]@{ method = $Method; lang = $Lang } |
            ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
    } catch { }
}

function Get-MethodByKey {
    param([string]$Key)
    $m = $Methods | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
    if (-not $m) { $m = $Methods[0] }
    return $m
}

# ---------------------------------------------------------------------------
#  Admin elevation
# ---------------------------------------------------------------------------
function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-AsAdmin {
    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`""
    )
    if ($InstallOnly) { $argList += "-InstallOnly" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

# ---------------------------------------------------------------------------
#  goodbyedpi.exe resolution (robust across machines)
# ---------------------------------------------------------------------------
function Resolve-GoodbyeDpiExe {
    $candidate = Join-Path (Join-Path $InstallRoot $Arch) "goodbyedpi.exe"
    if (Test-Path $candidate) { return $candidate }

    # Fallback: search the script tree for the arch-matching exe, then any exe.
    $matches = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "goodbyedpi.exe" -ErrorAction SilentlyContinue
    $archMatch = $matches | Where-Object { $_.FullName -match "\\$([regex]::Escape($Arch))\\" } | Select-Object -First 1
    if ($archMatch) { return $archMatch.FullName }
    if ($matches) { return ($matches | Select-Object -First 1).FullName }

    return $candidate
}

# ---------------------------------------------------------------------------
#  Service helpers
# ---------------------------------------------------------------------------
function Invoke-Sc {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $output = & sc.exe @Arguments 2>&1
    $text = ($output -join [Environment]::NewLine)
    if ($LASTEXITCODE -ne 0) {
        throw "sc.exe $($Arguments -join ' ') failed:`n$text"
    }
    return $text
}

function Write-InstallLog {
    param([string]$Message)
    try {
        $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    } catch { }
}

function Get-GoodbyeDpiService {
    return Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
}

function Install-GoodbyeDpiService {
    param([string]$MethodKey)

    $exe = Resolve-GoodbyeDpiExe
    if (!(Test-Path $exe)) {
        throw ($Strings[$script:Lang].ExeMissing -f $exe)
    }
    $method = Get-MethodByKey $MethodKey

    $existing = Get-GoodbyeDpiService
    if ($existing) {
        if ($existing.Status -ne "Stopped") {
            Invoke-Sc stop $ServiceName | Out-Null
            Start-Sleep -Milliseconds 800
        }
        Invoke-Sc delete $ServiceName | Out-Null
        Start-Sleep -Milliseconds 800
    }

    $binPath = '"' + $exe + '" ' + $method.Args
    Invoke-Sc create $ServiceName "binPath=" $binPath "start=" "auto" | Out-Null
    Invoke-Sc description $ServiceName $ServiceDescription | Out-Null
    Write-InstallLog "Installed service. Method=$($method.Key) Args=$($method.Args)"
}

function Start-GoodbyeDpiService {
    param([string]$MethodKey)
    if (!(Get-GoodbyeDpiService)) {
        Install-GoodbyeDpiService -MethodKey $MethodKey
    }
    $service = Get-GoodbyeDpiService
    if ($service.Status -ne "Running") {
        Invoke-Sc start $ServiceName | Out-Null
        Start-Sleep -Milliseconds 800
    }
}

function Stop-GoodbyeDpiService {
    $service = Get-GoodbyeDpiService
    if ($service -and $service.Status -ne "Stopped") {
        Invoke-Sc stop $ServiceName | Out-Null
        Start-Sleep -Milliseconds 800
    }
}

function Remove-GoodbyeDpiService {
    $service = Get-GoodbyeDpiService
    if ($service) {
        Stop-GoodbyeDpiService
        Invoke-Sc delete $ServiceName | Out-Null
        Start-Sleep -Milliseconds 800
    }
}

# ===========================================================================
#  Bootstrap
# ===========================================================================
if (!(Test-Admin)) {
    Restart-AsAdmin
}

$Config = Load-Config
$script:Lang = $Config.lang
$script:MethodKey = $Config.method

# --- Headless install path (used by the desktop shortcut on first run) ------
if ($InstallOnly) {
    try {
        Write-InstallLog "InstallOnly started. Admin=$(Test-Admin) Arch=$Arch Method=$script:MethodKey"
        Install-GoodbyeDpiService -MethodKey $script:MethodKey
        Start-GoodbyeDpiService -MethodKey $script:MethodKey
        Write-InstallLog "InstallOnly completed."
        exit 0
    }
    catch {
        Write-InstallLog "InstallOnly failed: $($_.Exception.Message)"
        throw
    }
}

# ===========================================================================
#  GUI
# ===========================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(430, 380)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true

$title = New-Object System.Windows.Forms.Label
$title.Text = "GoodbyeDPI"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(22, 18)
$form.Controls.Add($title)

$langButton = New-Object System.Windows.Forms.Button
$langButton.Size = New-Object System.Drawing.Size(46, 30)
$langButton.Location = New-Object System.Drawing.Point(352, 20)
$langButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($langButton)

$methodLabel = New-Object System.Windows.Forms.Label
$methodLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$methodLabel.AutoSize = $true
$methodLabel.Location = New-Object System.Drawing.Point(25, 66)
$form.Controls.Add($methodLabel)

$methodBox = New-Object System.Windows.Forms.ComboBox
$methodBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$methodBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$methodBox.Size = New-Object System.Drawing.Size(373, 26)
$methodBox.Location = New-Object System.Drawing.Point(25, 88)
$form.Controls.Add($methodBox)

$status = New-Object System.Windows.Forms.Label
$status.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(25, 128)
$form.Controls.Add($status)

$toggleButton = New-Object System.Windows.Forms.Button
$toggleButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$toggleButton.Size = New-Object System.Drawing.Size(373, 48)
$toggleButton.Location = New-Object System.Drawing.Point(25, 158)
$form.Controls.Add($toggleButton)

$note = New-Object System.Windows.Forms.Label
$note.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$note.Size = New-Object System.Drawing.Size(373, 46)
$note.Location = New-Object System.Drawing.Point(25, 214)
$form.Controls.Add($note)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$installButton.Size = New-Object System.Drawing.Size(182, 34)
$installButton.Location = New-Object System.Drawing.Point(25, 268)
$form.Controls.Add($installButton)

$removeButton = New-Object System.Windows.Forms.Button
$removeButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$removeButton.Size = New-Object System.Drawing.Size(182, 34)
$removeButton.Location = New-Object System.Drawing.Point(216, 268)
$form.Controls.Add($removeButton)

# ---------------------------------------------------------------------------
#  UI logic
# ---------------------------------------------------------------------------
$script:Suppress = $false   # guard against re-entrant combo events

function Get-Str { param([string]$Key) return $Strings[$script:Lang][$Key] }

function Populate-Methods {
    $script:Suppress = $true
    $methodBox.Items.Clear()
    foreach ($m in $Methods) {
        if ($script:Lang -eq "tr") { [void]$methodBox.Items.Add($m.Tr) }
        else { [void]$methodBox.Items.Add($m.En) }
    }
    $idx = 0
    for ($i = 0; $i -lt $Methods.Count; $i++) {
        if ($Methods[$i].Key -eq $script:MethodKey) { $idx = $i; break }
    }
    $methodBox.SelectedIndex = $idx
    $script:Suppress = $false
}

function Update-Note {
    $m = Get-MethodByKey $script:MethodKey
    if ($m.Dns) {
        $note.Text = Get-Str "NotePresetDns"
        $note.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    } else {
        $note.Text = Get-Str "NoteManualDns"
        $note.ForeColor = [System.Drawing.Color]::FromArgb(178, 90, 0)
    }
}

function Refresh-Ui {
    $title.Text = "GoodbyeDPI"
    $form.Text = Get-Str "Title"
    $methodLabel.Text = Get-Str "Method"
    $langButton.Text = Get-Str "BtnLang"
    $installButton.Text = Get-Str "BtnReinstall"
    $removeButton.Text = Get-Str "BtnRemove"
    Update-Note

    $service = Get-GoodbyeDpiService
    if (!$service) {
        $status.Text = Get-Str "StatusNotInst"
        $toggleButton.Text = Get-Str "BtnInstallOn"
        $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(42, 130, 72)
        $toggleButton.ForeColor = [System.Drawing.Color]::White
        return
    }
    $service.Refresh()
    if ($service.Status -eq "Running") {
        $status.Text = Get-Str "StatusRunning"
        $toggleButton.Text = Get-Str "BtnTurnOff"
        $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(178, 45, 45)
        $toggleButton.ForeColor = [System.Drawing.Color]::White
    } else {
        $status.Text = Get-Str "StatusStopped"
        $toggleButton.Text = Get-Str "BtnTurnOn"
        $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(42, 130, 72)
        $toggleButton.ForeColor = [System.Drawing.Color]::White
    }
}

function Show-Error {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($Message, (Get-Str "ErrTitle"), "OK", "Error") | Out-Null
}

# --- events ----------------------------------------------------------------
$langButton.Add_Click({
    if ($script:Lang -eq "tr") { $script:Lang = "en" } else { $script:Lang = "tr" }
    Save-Config -Method $script:MethodKey -Lang $script:Lang
    Populate-Methods
    Refresh-Ui
})

$methodBox.Add_SelectedIndexChanged({
    if ($script:Suppress) { return }
    $sel = $methodBox.SelectedIndex
    if ($sel -lt 0) { return }
    $script:MethodKey = $Methods[$sel].Key
    Save-Config -Method $script:MethodKey -Lang $script:Lang
    Update-Note

    # If the service is currently running, reinstall with the new method live.
    try {
        $service = Get-GoodbyeDpiService
        if ($service -and $service.Status -eq "Running") {
            $status.Text = Get-Str "ApplyRunning"
            $form.Refresh()
            Install-GoodbyeDpiService -MethodKey $script:MethodKey
            Start-GoodbyeDpiService -MethodKey $script:MethodKey
        }
        Refresh-Ui
    }
    catch {
        Show-Error $_.Exception.Message
        Refresh-Ui
    }
})

$toggleButton.Add_Click({
    try {
        $service = Get-GoodbyeDpiService
        if ($service -and $service.Status -eq "Running") {
            Stop-GoodbyeDpiService
        } else {
            Start-GoodbyeDpiService -MethodKey $script:MethodKey
        }
        Refresh-Ui
    }
    catch {
        Show-Error $_.Exception.Message
        Refresh-Ui
    }
})

$installButton.Add_Click({
    try {
        Install-GoodbyeDpiService -MethodKey $script:MethodKey
        Start-GoodbyeDpiService -MethodKey $script:MethodKey
        Refresh-Ui
    }
    catch {
        Show-Error $_.Exception.Message
        Refresh-Ui
    }
})

$removeButton.Add_Click({
    try {
        Remove-GoodbyeDpiService
        Refresh-Ui
    }
    catch {
        Show-Error $_.Exception.Message
        Refresh-Ui
    }
})

Populate-Methods
Refresh-Ui
[void]$form.ShowDialog()
