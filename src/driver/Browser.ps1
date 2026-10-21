# ---------------------------------------------------------------------------
# Starting Edge (or Chrome) with its own clean profile and connecting to it.
# ---------------------------------------------------------------------------

function Find-Browser {
    param([string]$Preferred)
    if ($Preferred -and (Test-Path -LiteralPath $Preferred)) { return $Preferred }
    $list = New-Object System.Collections.ArrayList
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
        if (-not $base) { continue }
        [void]$list.Add((Join-Path $base 'Microsoft\Edge\Application\msedge.exe'))
    }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if (-not $base) { continue }
        [void]$list.Add((Join-Path $base 'Google\Chrome\Application\chrome.exe'))
    }
    foreach ($p in @('/opt/pw-browsers/chromium-1194/chrome-linux/chrome', '/usr/bin/microsoft-edge', '/usr/bin/google-chrome', '/usr/bin/chromium')) { [void]$list.Add($p) }
    foreach ($p in $list) { if (Test-Path -LiteralPath $p) { return $p } }
    return $null
}

function Start-TestBrowser {
    param([string]$BrowserPath, [string]$ProfileDir, [switch]$Headless, [switch]$NoSandbox)
    if (-not (Test-Path -LiteralPath $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null }
    $portFile = Join-Path $ProfileDir 'DevToolsActivePort'
    if (Test-Path -LiteralPath $portFile) { Remove-Item -LiteralPath $portFile -Force -ErrorAction SilentlyContinue }
    $argList = @(
        '--remote-debugging-port=0',
        ('--user-data-dir="' + $ProfileDir + '"'),
        '--no-first-run', '--no-default-browser-check', '--disable-sync',
        '--disable-features=msEdgeFirstRunExperience,msUndersideButton,msEdgeSidebarV2',
        '--window-size=1300,940', '--window-position=40,20',
        '--disable-popup-blocking', '--disable-logging', '--log-level=3'
    )
    if ($Headless) { $argList += '--headless=new' }
    if ($NoSandbox) { $argList += '--no-sandbox' }
    $argList += 'about:blank'
    $proc = Start-Process -FilePath $BrowserPath -ArgumentList $argList -PassThru
    $port = $null
    for ($i = 0; $i -lt 100; $i++) {
        Start-Sleep -Milliseconds 200
        if (Test-Path -LiteralPath $portFile) {
            $lines = @(Get-Content -LiteralPath $portFile -ErrorAction SilentlyContinue)
            if ($lines.Count -ge 1 -and $lines[0] -match '^\d+$') { $port = [int]$lines[0]; break }
        }
    }
    if (-not $port) {
        throw ('The browser started but would not let the tool connect. This usually means a policy blocks it. ' +
               'In the browser go to edge://policy and look for RemoteDebuggingAllowed or DeveloperToolsAvailability.')
    }
    $target = $null
    for ($i = 0; $i -lt 50 -and -not $target; $i++) {
        try {
            $targets = Get-LocalJson ('http://127.0.0.1:' + $port + '/json/list')
            foreach ($t in $targets) {
                if ((Get-Field $t 'type') -eq 'page') {
                    if (-not $target) { $target = $t }
                    if ((Get-Field $t 'url') -eq 'about:blank') { $target = $t; break }
                }
            }
        } catch { }
        if (-not $target) { Start-Sleep -Milliseconds 200 }
    }
    if (-not $target) { throw 'Could not find the browser tab to control.' }
    $conn = New-CdpConnection (Get-Field $target 'webSocketDebuggerUrl')
    return [pscustomobject]@{ Process = $proc; Port = $port; Conn = $conn; ProfileDir = $ProfileDir; TargetId = (Get-Field $target 'id') }
}

function Stop-TestBrowser {
    param($Browser, [switch]$ClearProfile)
    if (-not $Browser) { return }
    try {
        $ver = Get-LocalJson ('http://127.0.0.1:' + $Browser.Port + '/json/version')
        $bc = New-CdpConnection (Get-Field $ver 'webSocketDebuggerUrl')
        try { Invoke-Cdp $bc 'Browser.close' '{}' 5 | Out-Null } catch { }
        Close-CdpConnection $bc
    } catch { }
    Close-CdpConnection $Browser.Conn
    try { if (-not $Browser.Process.HasExited) { $Browser.Process.WaitForExit(5000) | Out-Null } } catch { }
    try { if (-not $Browser.Process.HasExited) { $Browser.Process.Kill() } } catch { }
    if ($ClearProfile) {
        for ($i = 0; $i -lt 10; $i++) {
            try { Remove-Item -LiteralPath $Browser.ProfileDir -Recurse -Force -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 500 }
        }
    }
}

function Test-BrowserAlive {
    param($Browser)
    try { return ($Browser.Conn.Ws.State -eq 'Open') } catch { return $false }
}

function Initialize-Page {
    param($Conn, [string]$ToolbarJs, [switch]$Auto)
    Invoke-Cdp $Conn 'Page.enable' | Out-Null
    $src = $ToolbarJs
    if ($Auto) { $src = 'window.__a11yAuto = true;' + "`n" + $ToolbarJs }
    Invoke-Cdp $Conn 'Page.addScriptToEvaluateOnNewDocument' ('{"source":' + (ConvertTo-JsString $src) + '}') | Out-Null
    try { Invoke-Cdp $Conn 'Emulation.setFocusEmulationEnabled' '{"enabled":true}' | Out-Null } catch { }
    try { Invoke-Cdp $Conn 'Page.bringToFront' | Out-Null } catch { }
}

function Open-Url {
    param($Conn, [string]$Url, [int]$TimeoutSec = 45)
    Invoke-Cdp $Conn 'Page.navigate' ('{"url":' + (ConvertTo-JsString $Url) + '}') | Out-Null
    Wait-PageReady $Conn $TimeoutSec
}

function Wait-PageReady {
    param($Conn, [int]$TimeoutSec = 45)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    Start-Sleep -Milliseconds 300
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $state = Invoke-Js $Conn 'document.readyState' -TimeoutSec 10
            if ($state -eq 'complete') { break }
        } catch { }
        Start-Sleep -Milliseconds 300
    }
}
