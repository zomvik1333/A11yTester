# Proves the Edge snippet catches its planted problems and the clean page stays clean.
# Run from the repo folder:  powershell -ExecutionPolicy Bypass -File .\tests\Run-SnippetTests.ps1
param([switch]$Headless, [switch]$NoSandbox, [string]$BrowserPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
& (Join-Path $root 'build.ps1')
. (Join-Path $root 'src/driver/Cdp.ps1')
. (Join-Path $root 'src/driver/Browser.ps1')
$snippet = Get-Content -LiteralPath (Join-Path $root 'A11ySnippet.js') -Raw
$site = (Join-Path $root 'test-site').Replace('\', '/')
if (-not $site.StartsWith('/')) { $site = '/' + $site }
$expected = [ordered]@{}
foreach ($line in Get-Content -LiteralPath (Join-Path $root 'tests/snippet-expected.txt')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
    $p = $line -split "`t"
    $rules = @(); if ($p.Count -gt 1) { $rules = @($p[1] -split ' ' | Where-Object { $_ }) }
    $expected[$p[0]] = $rules
}
$profileDir = Join-Path ([IO.Path]::GetTempPath()) ('a11ysnip-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$b = Start-TestBrowser (Find-Browser $BrowserPath) $profileDir -Headless:$Headless -NoSandbox:$NoSandbox
$fail = 0
try {
    $c = $b.Conn
    Invoke-Cdp $c 'Page.enable' | Out-Null
    Invoke-Cdp $c 'Emulation.setFocusEmulationEnabled' '{"enabled":true}' | Out-Null
    foreach ($page in $expected.Keys) {
        Open-Url $c ('file://' + $site + '/' + $page)
        Set-Viewport $c 1280 800 400
        Invoke-Js $c $snippet | Out-Null
        $panel = Invoke-Js $c "!!document.getElementById('__a11y_toolbar_host')"
        if (-not $panel) { Write-Host "NO PANEL on $page" -ForegroundColor Red; $fail++ }
        Invoke-Js $c '__a11y.snip.clear(); __a11y.snip.testScreen("Test", "Open the page."); true' | Out-Null
        Set-Viewport $c 320 640 900
        Invoke-Js $c '__a11y.snip.checkZoom(400); true' | Out-Null
        Clear-Viewport $c
        $got = @(Invoke-Js $c '__a11y.snip.data().screens[0].issues.map(function(f){return f.rule})')
        $html = [string](Invoke-Js $c '__a11y.snip.reportHtml()')
        if ($html.Length -lt 2000) { Write-Host "REPORT TOO SHORT on $page" -ForegroundColor Red; $fail++ }
        $tr = @(Invoke-Js $c '__a11y.snip.transcript()')
        Write-Host ("{0}  found {1}  transcript lines {2}" -f $page, (($got | Sort-Object -Unique) -join ' '), $tr.Count)
        foreach ($r in $expected[$page]) { if ($got -notcontains $r) { Write-Host "MISSING  $page  $r" -ForegroundColor Red; $fail++ } }
        if ($expected[$page].Count -eq 0 -and $page -eq 'clean.html' -and $got.Count -gt 0) { Write-Host ('UNEXPECTED on clean page  ' + ($got -join ', ')) -ForegroundColor Red; $fail++ }
        if ($got -contains 'tool-error') {
            $e = Invoke-Js $c '__a11y.snip.data().screens[0].issues.filter(function(f){return f.rule==="tool-error"}).map(function(f){return f.params.module+": "+f.dev}).join(" | ")'
            Write-Host "TOOL ERROR on $page  $e" -ForegroundColor Red; $fail++
        }
    }
} finally { Stop-TestBrowser $b -ClearProfile }
if ($fail -gt 0) { Write-Host "$fail problem(s)." -ForegroundColor Red; exit 1 }
Write-Host 'PASS. The snippet caught every planted problem and the clean page stayed clean.' -ForegroundColor Green
exit 0
