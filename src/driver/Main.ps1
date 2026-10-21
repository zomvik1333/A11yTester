# ---------------------------------------------------------------------------
# Main program. Asks a few questions, opens the browser, runs the tests and
# writes the report.
# ---------------------------------------------------------------------------

function Read-SettingsFile {
    param([string]$Path)
    $s = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) { return $s }
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { continue }
        $s[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim()
    }
    return $s
}

function Write-SettingsFile {
    param([string]$Path, [string]$AppName, [string]$AppLink, [string]$TestedBy)
    $text = @"
# A11y Tester settings for one app. Edit in Notepad. Lines starting with # are notes.

# App
AppName = $AppName
AppLink = $AppLink
Environment = Test
# Any address starting with one of these is refused. Separate several with a comma.
ProductionAddresses =

# Run
# A list of links to test one after another, one per line, used by mode 2.
LinksFile =
MaxTabStops = 150
ClearLoginAfterRun = yes

# Report
TestedBy = $TestedBy
ResultsFolder =
"@
    Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
}

function Read-Choice {
    param([string]$Prompt, [string]$Default)
    $a = Read-Host ($Prompt + ' [' + $Default + ']')
    if (-not $a) { return $Default }
    return $a.Trim()
}

function Get-YesNo {
    param($Value, [bool]$Default)
    if ($null -eq $Value -or "$Value" -eq '') { return $Default }
    return ("$Value" -match '^(y|yes|true|1|on)$')
}

function Select-App {
    param([string]$AppsDir, [string]$AppName, [string]$Url, [switch]$NonInteractive)
    if ($AppName) {
        $path = Join-Path $AppsDir ($AppName + '.txt')
        if (-not (Test-Path -LiteralPath $path)) { Write-SettingsFile $path $AppName $Url $env:USERNAME }
        return $path
    }
    $files = @(Get-ChildItem -LiteralPath $AppsDir -Filter '*.txt' -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($files.Count -gt 0 -and -not $NonInteractive) {
        Write-Host ''
        Write-Host 'Which app do you want to test?' -ForegroundColor White
        for ($i = 0; $i -lt $files.Count; $i++) { Write-Host ('  ' + ($i + 1) + '. ' + [IO.Path]::GetFileNameWithoutExtension($files[$i].Name)) }
        Write-Host ('  ' + ($files.Count + 1) + '. Add a new app')
        $c = Read-Choice 'Type a number' '1'
        $n = 0
        if ([int]::TryParse($c, [ref]$n) -and $n -ge 1 -and $n -le $files.Count) { return $files[$n - 1].FullName }
    }
    Write-Host ''
    Write-Host "Let's set up a new app. You only do this once." -ForegroundColor White
    $name = ''
    while (-not $name) { $name = (Read-Host 'App name, for example Budget Tool').Trim() }
    $name = ($name -replace '[\\/:*?"<>|]', ' ').Trim()
    $link = ''
    while (-not $link) { $link = (Read-Host 'Paste the dev or test link for this app').Trim() }
    $by = Read-Choice 'Your name for the report' $env:USERNAME
    $path = Join-Path $AppsDir ($name + '.txt')
    Write-SettingsFile $path $name $link $by
    Write-Host ('Saved. You can change these later in ' + $path) -ForegroundColor DarkGray
    return $path
}

function Show-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  A11y Tester' -ForegroundColor Cyan -NoNewline
    Write-Host ('  version ' + $Script:ToolVersion) -ForegroundColor DarkGray
    Write-Host '  WCAG 2.2 zoom, keyboard and screen reader testing. Everything stays on this computer.' -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-A11yMain {
    param(
        [string]$AppName, [string]$Url, [ValidateSet('', 'Guided', 'Links')][string]$Mode = '', [string[]]$Links,
        [string]$DataDir, [string]$ResultsDir, [string]$BrowserPath, [switch]$Headless, [switch]$NoSandbox, [switch]$NoOpen,
        [string[]]$Skip = @(), [switch]$KeepLogin
    )
    $ErrorActionPreference = 'Stop'
    if ($Links) { $Links = @($Links | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $nonInteractive = [bool]($Mode -and ($Mode -eq 'Links') -and $Links)
    if (-not $nonInteractive) { Show-Banner }

    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not $docs) { $docs = $HOME }
    if (-not $DataDir) { $DataDir = Join-Path $docs 'A11y Tester Data' }
    $appsDir = Join-Path $DataDir 'Apps'
    New-Item -ItemType Directory -Path $appsDir -Force | Out-Null

    $settingsPath = Select-App $appsDir $AppName $Url -NonInteractive:$nonInteractive
    $set = Read-SettingsFile $settingsPath
    $app = [string]$set['AppName']
    if (-not $app) { $app = [IO.Path]::GetFileNameWithoutExtension($settingsPath) }
    $link = [string]$set['AppLink']
    if ($Url) { $link = $Url }

    foreach ($p in (([string]$set['ProductionAddresses']) -split ',')) {
        $p = $p.Trim()
        if ($p -and $link -and $link.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Host ''
            Write-Host 'Stopped. That link matches a production address in your settings. This tool only runs on dev and test.' -ForegroundColor Red
            return
        }
    }

    if (-not $Mode) {
        Write-Host ''
        Write-Host 'How do you want to test?' -ForegroundColor White
        Write-Host '  1. I will click through the screens myself and press Test This Screen on each one'
        Write-Host '  2. Test a list of links one after another'
        $c = Read-Choice 'Type a number' '1'
        $Mode = 'Guided'
        if ($c -eq '2') { $Mode = 'Links' }
    }
    if ($Mode -eq 'Links' -and -not $Links) {
        $lf = [string]$set['LinksFile']
        if ($lf -and (Test-Path -LiteralPath $lf)) { $Links = @(Get-Content -LiteralPath $lf | Where-Object { $_.Trim() }) }
        else {
            Write-Host 'Paste the links to test, one per line. Press Enter on an empty line when done.' -ForegroundColor White
            $tmp = New-Object System.Collections.ArrayList
            while ($true) { $l = Read-Host; if (-not $l) { break }; [void]$tmp.Add($l.Trim()) }
            $Links = $tmp.ToArray()
        }
        if (-not $Links -or $Links.Count -eq 0) { Write-Host 'No links given, so there is nothing to test.' -ForegroundColor Yellow; return }
    }

    if (-not $ResultsDir) {
        $ResultsDir = [string]$set['ResultsFolder']
        if (-not $ResultsDir) { $ResultsDir = Join-Path $docs 'A11y Tester Results' }
    }
    $stamp = (Get-Date).ToString('yyyy-MM-dd HHmm')
    $runDir = Join-Path (Join-Path $ResultsDir $app) $stamp
    $shotDir = Join-Path $runDir 'Screenshots'
    New-Item -ItemType Directory -Path $shotDir -Force | Out-Null
    $Script:LogPath = Join-Path $runDir 'Run Log.txt'
    Write-Log ('A11y Tester ' + $Script:ToolVersion + ' PowerShell ' + $PSVersionTable.PSVersion + ' app ' + $app + ' mode ' + $Mode)

    $appData = Join-Path $DataDir $app
    New-Item -ItemType Directory -Path $appData -Force | Out-Null

    $maxTabs = 150
    $mt = 0
    if ([int]::TryParse([string]$set['MaxTabStops'], [ref]$mt) -and $mt -gt 10) { $maxTabs = $mt }
    $ctx = [pscustomobject]@{
        AppName = $app; Environment = ([string]$set['Environment']); TestedBy = ([string]$set['TestedBy'])
        RunDir = $runDir; ShotDir = $shotDir; ScreenNum = 0; ShotCount = 0; MaxShots = 400; MaxTabs = $maxTabs; Skip = $Skip
    }
    if (-not $ctx.Environment) { $ctx.Environment = 'Test' }
    if (-not $ctx.TestedBy) { $ctx.TestedBy = $env:USERNAME }
    if (-not $ctx.TestedBy) { $ctx.TestedBy = $env:USER }

    $exe = Find-Browser $BrowserPath
    if (-not $exe) { Write-Host 'Could not find Microsoft Edge or Google Chrome on this computer.' -ForegroundColor Red; return }
    Write-Host ''
    Write-Host ('Opening ' + [IO.Path]::GetFileNameWithoutExtension($exe) + ' with a separate clean profile...') -ForegroundColor White
    $profileDir = Join-Path $DataDir 'Browser Profile'
    $browser = $null
    $screens = New-Object System.Collections.ArrayList
    try {
        $browser = Start-TestBrowser $exe $profileDir -Headless:$Headless -NoSandbox:$NoSandbox
        $conn = $browser.Conn
        Initialize-Page $conn $Script:JsToolbar -Auto:($Mode -eq 'Links')

        if ($Mode -eq 'Links') {
            $i = 0
            foreach ($u in $Links) {
                $i++
                Write-Host ('Opening link ' + $i + ' of ' + $Links.Count) -ForegroundColor DarkGray
                try {
                    Open-Url $conn $u
                    $here = [string](Invoke-Js $conn 'location.href')
                    if ($here -match '^(chrome|edge)-error:') { throw 'The page would not load. Check the link and that you are on the network.' }
                    $s = Invoke-ScreenTest $conn $ctx @('Open this link in the browser. ' + $u)
                    [void]$screens.Add($s)
                } catch { Write-Step ('Could not test ' + $u + '. ' + $_.Exception.Message) 'Yellow' }
            }
        } else {
            if ($link) { Open-Url $conn $link 60 }
            Write-Host ''
            Write-Host 'The browser is open.' -ForegroundColor White
            Write-Host '  1. Log in like normal, MFA included.'
            Write-Host '  2. Click the green I''m Logged In button in the bottom right corner of the page.'
            Write-Host '  3. Go to any screen and click Test This Screen. Keep your hands off while it runs, about 30 seconds.'
            Write-Host '  4. Repeat for each screen, then click Done. You can also press Q here to finish.'
            Write-Host ''
            $done = $false
            while (-not $done) {
                if (-not (Test-BrowserAlive $browser)) { Write-Host 'The browser was closed.' -ForegroundColor Yellow; break }
                $cmds = $null
                try { $cmds = Invoke-Js $conn '(window.__a11yTb ? __a11yTb.take() : [])' -TimeoutSec 15 } catch {
                    if ("$_" -match 'closed') { break }
                }
                foreach ($c in @($cmds)) {
                    if ($c -eq 'loggedin') { Write-Host 'Logged in. Go to a screen and click Test This Screen.' -ForegroundColor Green }
                    elseif ($c -eq 'test') {
                        $trail = @()
                        try { $trail = @(Invoke-Js $conn '__a11yTb.trail()') } catch { }
                        $dirs = @('Log in.') + @($trail | Select-Object -Last 12)
                        try { [void]$screens.Add((Invoke-ScreenTest $conn $ctx $dirs)) }
                        catch { Write-Step ('Could not test this screen. ' + $_.Exception.Message) 'Yellow'; try { Invoke-Js $conn '__a11yTb.show("That screen could not be tested. Try again.")' | Out-Null } catch { } }
                    }
                    elseif ($c -eq 'done') { $done = $true }
                }
                try {
                    if ([Console]::KeyAvailable) { $k = [Console]::ReadKey($true); if ($k.Key -eq 'Q') { $done = $true } }
                } catch { }
                if (-not $done) { Start-Sleep -Milliseconds 400 }
            }
        }
    } catch {
        Write-Host ''
        Write-Host ('Stopped. ' + $_.Exception.Message) -ForegroundColor Red
        Write-Log ('FATAL ' + $_.Exception.Message + ' ' + $_.ScriptStackTrace)
    } finally {
        $clear = (Get-YesNo $set['ClearLoginAfterRun'] $true) -and -not $KeepLogin
        Stop-TestBrowser $browser -ClearProfile:$clear
    }

    if ($screens.Count -eq 0) {
        Write-Host ''
        Write-Host 'No screens were tested, so there is no report this time.' -ForegroundColor Yellow
        return
    }
    Write-Host ''
    Write-Host 'Writing the report...' -ForegroundColor White
    $model = Get-ReportModel $screens $appData
    $report = Write-Report $model $ctx
    Write-Host ''
    Write-Host ('Done. ' + $model.Issues.Count + ' issue(s) across ' + $screens.Count + ' screen(s).') -ForegroundColor Green
    Write-Host ('Report saved in ' + $runDir) -ForegroundColor Green
    Write-Log 'Report written.'
    if (-not $NoOpen) {
        try { Invoke-Item -LiteralPath $report } catch { }
        try { Invoke-Item -LiteralPath $runDir } catch { }
    }
    return $runDir
}
