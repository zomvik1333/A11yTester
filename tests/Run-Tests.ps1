# Proves every check catches its planted problem and the clean page stays clean.
# Run from the repo folder:  powershell -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
param([switch]$Headless, [switch]$NoSandbox, [string]$BrowserPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
& (Join-Path $root 'build.ps1')
$work = Join-Path ([IO.Path]::GetTempPath()) ('a11ytest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$site = (Join-Path $root 'test-site').Replace('\', '/')
if (-not $site.StartsWith('/')) { $site = '/' + $site }
$expected = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $root 'tests\expected.txt')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
    $p = $line -split "`t"
    $rules = @()
    if ($p.Count -gt 1) { $rules = @($p[1] -split ' ' | Where-Object { $_ }) }
    $expected[$p[0]] = $rules
}
$links = (@($expected.Keys | Sort-Object) | ForEach-Object { 'file://' + $site + '/' + $_ }) -join ','
$args2 = @{ AppName = 'SelfTest'; Mode = 'Links'; Links = $links; DataDir = (Join-Path $work 'data'); ResultsDir = (Join-Path $work 'results'); NoOpen = $true; Headless = $Headless; NoSandbox = $NoSandbox }
if ($BrowserPath) { $args2['BrowserPath'] = $BrowserPath }
& (Join-Path $root 'A11yTester.ps1') @args2
$tsv = Get-ChildItem -LiteralPath (Join-Path $work 'results') -Recurse -Filter 'findings-data.tsv' | Select-Object -First 1
if (-not $tsv) { Write-Host 'FAIL. No results were written.' -ForegroundColor Red; exit 1 }
$found = @{}
foreach ($line in Get-Content -LiteralPath $tsv.FullName) {
    $p = $line -split "`t"
    $page = ($p[0] -split '/')[-1]
    if (-not $found.ContainsKey($page)) { $found[$page] = @() }
    $found[$page] += $p[1]
}
$fail = 0
foreach ($page in $expected.Keys | Sort-Object) {
    $got = @(); if ($found.ContainsKey($page)) { $got = $found[$page] }
    foreach ($r in $expected[$page]) { if ($got -notcontains $r) { Write-Host ("MISSING  $page  $r") -ForegroundColor Red; $fail++ } }
    if ($expected[$page].Count -eq 0 -and $got.Count -gt 0) { Write-Host ("UNEXPECTED on clean page  " + ($got -join ', ')) -ForegroundColor Red; $fail++ }
    foreach ($r in $got) { if ($r -eq 'tool-error') { Write-Host ("TOOL ERROR on $page") -ForegroundColor Red; $fail++ } }
}
if ($fail -gt 0) { Write-Host "$fail problem(s). Results kept in $work" -ForegroundColor Red; exit 1 }
Write-Host 'PASS. Every planted problem was caught and the clean page stayed clean.' -ForegroundColor Green
Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
exit 0
