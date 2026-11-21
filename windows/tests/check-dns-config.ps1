$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$cmdFiles = Get-ChildItem (Join-Path $repoRoot 'windows') -Filter *.cmd
$failures = New-Object System.Collections.Generic.List[string]
$dnsLines = New-Object System.Collections.Generic.List[string]

foreach ($f in $cmdFiles) {
    $text = [IO.File]::ReadAllText($f.FullName)
    $lines = $text -split "`r?`n"

    foreach ($line in $lines) {
        if ($line -match '--dns-addr') {
            $dnsLines.Add("$($f.Name): $($line.Trim())")
            if ($line -notmatch '--dns-addr 9\.9\.9\.9') { $failures.Add("$($f.Name): --dns-addr is not Quad9") }
            if ($line -notmatch '--dns-port 9953') { $failures.Add("$($f.Name): --dns-port is not 9953") }
        }
        if ($line -match '--dnsv6-addr') {
            if ($line -notmatch '--dnsv6-addr 2620:fe::fe') { $failures.Add("$($f.Name): --dnsv6-addr is not Quad9") }
            if ($line -notmatch '--dnsv6-port 9953') { $failures.Add("$($f.Name): --dnsv6-port is not 9953") }
        }
    }

    foreach ($bad in '77.88.8.8', '77.88.8.1', '2a02:6b8', '--dns-port 1253', '--dnsv6-port 1253') {
        if ($text.Contains($bad)) { $failures.Add("$($f.Name): still contains '$bad'") }
    }

    if ($text -match '--dns-addr' -and $text -notmatch 'ipconfig /flushdns') {
        $failures.Add("$($f.Name): DNS-redirecting script does not flush the DNS cache")
    }
}

# Every script that redirects DNS must also redirect the v6 resolver.
foreach ($f in $cmdFiles) {
    $text = [IO.File]::ReadAllText($f.FullName)
    if ($text -match '--dns-addr' -and $text -notmatch '--dnsv6-addr') {
        $failures.Add("$($f.Name): missing --dnsv6-addr")
    }
}

Write-Output "DNS-redirecting command lines found: $($dnsLines.Count)"
$dnsLines | ForEach-Object { Write-Output "  $_" }

if ($failures.Count -gt 0) {
    Write-Output ""
    Write-Output "FAILURES:"
    $failures | ForEach-Object { Write-Output "  - $_" }
    exit 1
}

Write-Output ""
Write-Output "OK: every DNS-redirecting script uses Quad9 9.9.9.9:9953 / 2620:fe::fe:9953,"
Write-Output "    no script references Yandex, and every installer flushes the DNS cache."
