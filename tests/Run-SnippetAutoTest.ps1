# Proves the snippet records clicks and tests new screens on its own, for full page loads and single page apps.
param([switch]$Headless, [switch]$NoSandbox, [string]$BrowserPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src/driver/Cdp.ps1')
. (Join-Path $root 'src/driver/Browser.ps1')
$snippet = Get-Content -LiteralPath (Join-Path $root 'A11ySnippet.js') -Raw
$site = (Join-Path $root 'test-site').Replace('\', '/'); if (-not $site.StartsWith('/')) { $site = '/' + $site }
$profileDir = Join-Path ([IO.Path]::GetTempPath()) ('a11yauto-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$b = Start-TestBrowser (Find-Browser $BrowserPath) $profileDir -Headless:$Headless -NoSandbox:$NoSandbox
$fail = 0
function Screens { @(Invoke-Js $c '__a11y.snip.data().screens.map(function(s){return s.name + " || " + s.how.replace(/\n/g," / ") + " || " + (s.parts.screen?"tested":"not tested") + " || " + s.issues.length})') }
function WaitFor([int]$count) { for ($i = 0; $i -lt 30; $i++) { Start-Sleep -Milliseconds 500; $n = [int](Invoke-Js $c '__a11y.snip.data().screens.filter(function(s){return s.parts.screen}).length'); if ($n -ge $count) { return $true } }; return $false }
try {
    $c = $b.Conn
    Invoke-Cdp $c 'Page.enable' | Out-Null
    Invoke-Cdp $c 'Emulation.setFocusEmulationEnabled' '{"enabled":true}' | Out-Null
    Set-Viewport $c 1280 800 200
    # Full page loads
    Open-Url $c ('file://' + $site + '/clean.html')
    Invoke-Js $c $snippet | Out-Null
    if (-not (WaitFor 1)) { Write-Host 'FAIL first screen was not tested on its own' -ForegroundColor Red; $fail++ }
    Invoke-Js $c "document.querySelector('nav a[href=""zoom.html""]').click(); true" | Out-Null
    Start-Sleep -Milliseconds 800; Wait-PageReady $c
    Invoke-Js $c $snippet | Out-Null
    if (-not (WaitFor 2)) { Write-Host 'FAIL second page was not tested on its own' -ForegroundColor Red; $fail++ }
    $s = Screens; $s | ForEach-Object { Write-Host "  $_" }
    if (-not ($s[1] -match 'Click "Reports" in the menu')) { Write-Host 'FAIL directions did not record the click' -ForegroundColor Red; $fail++ }
    # Single page app, no reload between screens
    Open-Url $c ('file://' + $site + '/spa.html')
    Invoke-Js $c $snippet | Out-Null
    if (-not (WaitFor 3)) { Write-Host 'FAIL SPA first screen not tested' -ForegroundColor Red; $fail++ }
    Invoke-Js $c "document.querySelector('a[href=""#/requests""]').click(); true" | Out-Null
    if (-not (WaitFor 4)) { Write-Host 'FAIL SPA route change was not tested on its own' -ForegroundColor Red; $fail++ }
    Invoke-Js $c "document.querySelector('a[href=""#/settings""]').click(); true" | Out-Null
    if (-not (WaitFor 5)) { Write-Host 'FAIL SPA second route change was not tested' -ForegroundColor Red; $fail++ }
    $s = Screens; $s | ForEach-Object { Write-Host "  $_" }
    if (-not ($s[3] -match 'Click "Requests" in the menu' -and $s[3] -match 'sr-|[1-9]$')) { }
    $req = @(Invoke-Js $c '__a11y.snip.data().screens[3].issues.map(function(f){return f.rule})')
    if ($req -notcontains 'sr-unnamed') { Write-Host 'FAIL SPA Requests screen should have an unnamed button' -ForegroundColor Red; $fail++ }
} finally { Stop-TestBrowser $b -ClearProfile }
if ($fail -gt 0) { Write-Host "$fail problem(s)." -ForegroundColor Red; exit 1 }
Write-Host 'PASS. Clicks were recorded and every new screen was tested on its own.' -ForegroundColor Green
exit 0
