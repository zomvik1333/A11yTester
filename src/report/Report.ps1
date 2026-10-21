# ---------------------------------------------------------------------------
# Builds the Word report, the issue list and the screen reader transcripts.
# ---------------------------------------------------------------------------

function Format-Template {
    param([string]$Template, $Params)
    $out = $Template
    if ($Params -is [System.Collections.IDictionary]) {
        foreach ($k in @($Params.Keys)) { $out = $out.Replace('{' + $k + '}', [string]$Params[$k]) }
    }
    return [regex]::Replace($out, '\{[a-z]+\}', 'this item')
}

function Get-ShortHash {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    return (($bytes[0..5] | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-SevRank { param([string]$Sev) switch ($Sev) { 'High' { 3 } 'Medium' { 2 } default { 1 } } }

function Read-Image {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    return [System.IO.File]::ReadAllBytes($Path)
}

function Get-ReportModel {
    # Groups findings, assigns stable issue numbers, compares with the last run.
    param($Screens, [string]$AppDataDir)
    $all = New-Object System.Collections.ArrayList
    foreach ($s in $Screens) { foreach ($f in $s.Findings) { [void]$all.Add($f) } }

    # Duplicate page titles across screens
    $byTitle = @{}
    foreach ($s in $Screens) { if ($s.Title) { $t = $s.Title.ToLower(); if (-not $byTitle.ContainsKey($t)) { $byTitle[$t] = New-Object System.Collections.ArrayList }; [void]$byTitle[$t].Add($s) } }
    foreach ($t in $byTitle.Keys) {
        $list = $byTitle[$t]
        $distinct = @($list | Select-Object -ExpandProperty Key -Unique)
        if ($distinct.Count -ge 2) {
            $f = New-Finding @{ rule = 'sr-dup-title'; sev = 'Low'; conf = 'confirmed'; params = @{ count = $distinct.Count; title = $list[0].Title }; sig = 'title|' + $t } 'Screen reader'
            $f.Screen = $list[0]
            $f.Dev = 'Same <title> on: ' + ((@($list | ForEach-Object { $_.Name }) | Select-Object -Unique) -join ', ')
            [void]$list[0].Findings.Add($f)
            [void]$all.Add($f)
        }
    }

    # Site wide: same rule and same element on at least 3 screens and half of them
    $screenCount = @($Screens).Count
    $groups = @{}
    foreach ($f in $all) {
        if (-not $f.Sig -or $f.Rule -eq 'tool-error') { continue }
        $k = $f.Rule + '#' + $f.Sig
        if (-not $groups.ContainsKey($k)) { $groups[$k] = New-Object System.Collections.ArrayList }
        [void]$groups[$k].Add($f)
    }
    $siteWide = New-Object System.Collections.ArrayList
    $siteWideMembers = @{}
    foreach ($k in $groups.Keys) {
        $g = $groups[$k]
        $scr = @($g | ForEach-Object { $_.Screen.Num } | Select-Object -Unique)
        if ($screenCount -ge 3 -and $scr.Count -ge 3 -and $scr.Count -ge ($screenCount / 2)) {
            [void]$siteWide.Add([pscustomobject]@{ First = $g[0]; Screens = @($g | ForEach-Object { $_.Screen } | Sort-Object Num -Unique); Key = $k })
            foreach ($f in $g) { $siteWideMembers[[System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($f)] = $true }
        }
    }

    # Stable issue numbers
    $idFile = Join-Path $AppDataDir 'issue-numbers.txt'
    $lastFile = Join-Path $AppDataDir 'last-run.txt'
    $ids = @{}; $next = 1
    if (Test-Path -LiteralPath $idFile) {
        foreach ($line in Get-Content -LiteralPath $idFile -Encoding UTF8) {
            $p = $line -split "`t"
            if ($p.Count -ge 2) { $ids[$p[0]] = [int]$p[1]; if ([int]$p[1] -ge $next) { $next = [int]$p[1] + 1 } }
        }
    }
    $last = @{}
    if (Test-Path -LiteralPath $lastFile) {
        foreach ($line in Get-Content -LiteralPath $lastFile -Encoding UTF8) {
            $p = $line -split "`t"
            if ($p.Count -ge 4) { $last[$p[0]] = @{ Screen = $p[1]; Title = $p[2]; ScreenName = $p[3] } }
        }
    }
    $assign = {
        param($f, [string]$keyText)
        $h = Get-ShortHash $keyText
        if (-not $ids.ContainsKey($h)) { $ids[$h] = $script:__next; $script:__next++ }
        $f.Hash = $h
        $f.Id = 'ADA ' + ([int]$ids[$h]).ToString('000')
        if ($last.ContainsKey($h)) { $f.Status = 'Still open' } elseif ($last.Count -gt 0) { $f.Status = 'New' } else { $f.Status = 'First run' }
    }
    $script:__next = $next
    foreach ($sw in $siteWide) { & $assign $sw.First ('ALL|' + $sw.Key) }
    foreach ($f in $all) {
        if ($siteWideMembers.ContainsKey([System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($f))) { continue }
        & $assign $f ($f.Screen.Key + '|' + $f.Rule + '|' + $f.Sig + '|' + (Format-Template '{text}{name}{alt}' $f.Params))
    }
    $next = $script:__next

    # Fixed since last run: issues on screens tested now that no longer show up
    $testedKeys = @{}
    foreach ($s in $Screens) { $testedKeys[$s.Key] = $true }
    $current = @{}
    foreach ($f in $all) { if ($f.Hash) { $current[$f.Hash] = $true } }
    foreach ($sw in $siteWide) { $current[$sw.First.Hash] = $true }
    $fixed = New-Object System.Collections.ArrayList
    foreach ($h in $last.Keys) {
        $e = $last[$h]
        if ($current.ContainsKey($h)) { continue }
        if ($e.Screen -eq 'ALL' -or $testedKeys.ContainsKey($e.Screen)) { [void]$fixed.Add([pscustomobject]@{ Id = ('ADA ' + ([int]$ids[$h]).ToString('000')); Title = $e.Title; Screen = $e.ScreenName }) }
    }

    # Save numbering and this run for next time
    $lines = New-Object System.Collections.ArrayList
    foreach ($k in $ids.Keys) { [void]$lines.Add($k + "`t" + $ids[$k]) }
    Set-Content -LiteralPath $idFile -Value $lines -Encoding UTF8
    $lines = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($sw in $siteWide) { $f = $sw.First; if (-not $seen.ContainsKey($f.Hash)) { $seen[$f.Hash] = 1; [void]$lines.Add($f.Hash + "`tALL`t" + $Script:Rules[$f.Rule].Title + "`tEvery screen") } }
    foreach ($f in $all) {
        if (-not $f.Hash -or $seen.ContainsKey($f.Hash) -or $f.Rule -eq 'tool-error') { continue }
        $seen[$f.Hash] = 1
        [void]$lines.Add($f.Hash + "`t" + $f.Screen.Key + "`t" + $Script:Rules[$f.Rule].Title + "`t" + $f.Screen.Name)
    }
    Set-Content -LiteralPath $lastFile -Value $lines -Encoding UTF8

    $perScreen = @{}
    foreach ($s in $Screens) {
        $perScreen[$s.Num] = @($s.Findings | Where-Object { -not $siteWideMembers.ContainsKey([System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($_)) } |
            Sort-Object @{ Expression = { Get-SevRank $_.Sev }; Descending = $true }, @{ Expression = { $_.Conf -ne 'confirmed' } })
    }
    $issues = New-Object System.Collections.ArrayList
    foreach ($sw in $siteWide) { [void]$issues.Add($sw.First) }
    foreach ($s in $Screens) { foreach ($f in $perScreen[$s.Num]) { if ($f.Rule -ne 'tool-error') { [void]$issues.Add($f) } } }

    return [pscustomobject]@{ Screens = $Screens; SiteWide = $siteWide; PerScreen = $perScreen; Issues = $issues; Fixed = $fixed; HadLastRun = ($last.Count -gt 0) }
}

function Add-IssueCard {
    param($Doc, $F, [string]$ScreenLabel, [string[]]$Directions)
    $rule = $Script:Rules[$F.Rule]
    if (-not $rule) { return }
    $conf = 'Confirmed'
    if ($F.Conf -ne 'confirmed') { $conf = 'Please check' }
    Add-DocxHeading $Doc ($F.Id + '. ' + $rule.Title) 3
    $rows = New-Object System.Collections.ArrayList
    [void]$rows.Add(@('Severity', ($F.Sev + ', ' + $conf)))
    [void]$rows.Add(@('Screen', $ScreenLabel))
    if ($Directions -and $Directions.Count) {
        $d = New-Object System.Collections.ArrayList
        $i = 0
        foreach ($x in $Directions) { $i++; [void]$d.Add("$i. $x") }
        [void]$rows.Add(@('How to get there', ($d -join "`n")))
    }
    if ($F.Phase -and $F.Phase -ne 'tool') { [void]$rows.Add(@('When it happens', $F.Phase)) }
    [void]$rows.Add(@('What we found', (Format-Template $rule.What $F.Params)))
    [void]$rows.Add(@('Who this affects', $rule.Who))
    [void]$rows.Add(@('Recommended fix', $rule.Fix))
    if ($F.Dev) { [void]$rows.Add(@('Note for developers', $F.Dev)) }
    $std = ''
    if ($rule.Wcag) { $std = 'WCAG 2.2 ' + $rule.Wcag + ' ' + $rule.WcagName }
    if ($rule.Dof) { $std += '. DOF checklist item ' + $rule.Dof }
    if ($std) { [void]$rows.Add(@('Rule broken', $std)) }
    if ($F.Status -and $F.Status -ne 'First run') { [void]$rows.Add(@('Since last run', $F.Status)) }
    Add-DocxTable $Doc $rows.ToArray() @(2300, 7780) -FirstColBold
    if ($F.Shot) {
        $bytes = Read-Image $F.Shot
        if ($bytes) { Add-DocxImage $Doc $bytes $F.ShotW $F.ShotH ('Screenshot for ' + $F.Id + ', the problem area is outlined in red') }
    }
}

function Write-Report {
    param($Model, $Ctx)
    $app = $Ctx.AppName
    $date = Get-Date
    $issues = $Model.Issues
    $confirmed = @($issues | Where-Object { $_.Conf -eq 'confirmed' })
    $high = @($issues | Where-Object { $_.Sev -eq 'High' }).Count
    $med = @($issues | Where-Object { $_.Sev -eq 'Medium' }).Count
    $low = @($issues | Where-Object { $_.Sev -eq 'Low' }).Count

    # Scorecard
    $failed = @{}; $checkOnly = @{}
    foreach ($f in $issues) {
        $w = $Script:Rules[$f.Rule].Wcag
        if (-not $w) { continue }
        if ($f.Conf -eq 'confirmed') { $failed[$w] = $true } else { $checkOnly[$w] = $true }
    }
    $score = New-Object System.Collections.ArrayList
    [void]$score.Add(@('Criterion', 'Name', 'Level', 'Result'))
    $nPass = 0; $nFail = 0; $nCheck = 0; $nPerson = 0; $nLater = 0
    foreach ($c in $Script:WcagList) {
        $res = ''
        if ($failed.ContainsKey($c[0])) { $res = 'Fail'; $nFail++ }
        elseif ($checkOnly.ContainsKey($c[0])) { $res = 'Please check'; $nCheck++ }
        elseif ($c[3] -eq 'Auto') { $res = 'Pass (automated)'; $nPass++ }
        elseif ($c[3] -eq 'Person') { $res = 'Needs a person'; $nPerson++ }
        else { $res = 'Not tested yet'; $nLater++ }
        [void]$score.Add(@($c[0], $c[1], $c[2], $res))
    }
    $result = 'No Automated Failures Found, Manual Checks Needed'
    if ($confirmed.Count -gt 0) { $result = 'Not Compliant' }

    $doc = New-Docx ($app + ' Accessibility Report')
    Add-DocxHeading $doc ($app + ' Accessibility Report') 0
    Add-DocxPara $doc ('WCAG 2.2 Level AA test, ' + $date.ToString('MMMM d, yyyy')) -Size 13 -Color '444444'
    Add-DocxTable $doc @(
        @('App', $app), @('Environment', $Ctx.Environment), @('Tested by', $Ctx.TestedBy), @('Date', $date.ToString('MMMM d, yyyy h:mm tt')),
        @('Screens tested', [string]@($Model.Screens).Count), @('Tool', ('A11y Tester ' + $Script:ToolVersion))
    ) @(2300, 7780) -FirstColBold

    Add-DocxHeading $doc 'Bottom line' 1
    $fill = 'FBEBEB'; $color = '9B1C1C'
    if ($result -ne 'Not Compliant') { $fill = 'E5F4E4'; $color = '1B5E20' }
    Add-DocxPara $doc $result -Bold -Size 18 -Color $color -Shade $fill
    $summary = 'We tested ' + @($Model.Screens).Count + ' screen(s) and found ' + $issues.Count + ' issue(s). ' +
        $high + ' are High, meaning they block someone completely. ' + $med + ' are Medium and ' + $low + ' are Low.'
    if ($result -ne 'Not Compliant') { $summary += ' Automated tests cannot check everything, so the Needs a Person section still has to be done before calling the app compliant.' }
    Add-DocxPara $doc $summary
    Add-DocxTable $doc @(
        @('Measure', 'Count'),
        @('Screens tested', [string]@($Model.Screens).Count),
        @('Issues, High', [string]$high), @('Issues, Medium', [string]$med), @('Issues, Low', [string]$low),
        @('Issues the tool is sure about', [string]$confirmed.Count),
        @('Issues that need a quick human look', [string]($issues.Count - $confirmed.Count)),
        @('WCAG criteria failed', [string]$nFail), @('WCAG criteria passed in automated tests', [string]$nPass),
        @('WCAG criteria needing a person', [string]$nPerson), @('WCAG criteria for later phases of this tool', [string]$nLater)
    ) @(6500, 3580) -Header

    if ($Model.HadLastRun) {
        Add-DocxHeading $doc 'Compared to last run' 1
        $new = @($issues | Where-Object { $_.Status -eq 'New' }).Count
        $open = @($issues | Where-Object { $_.Status -eq 'Still open' }).Count
        Add-DocxTable $doc @(@('Status', 'Count'), @('Fixed', [string]$Model.Fixed.Count), @('Still open', [string]$open), @('New', [string]$new)) @(6500, 3580) -Header
        if ($Model.Fixed.Count -gt 0) {
            Add-DocxPara $doc 'Fixed since last run' -Bold
            Add-DocxBullets $doc @($Model.Fixed | ForEach-Object { $_.Id + ', ' + $_.Title + ', ' + $_.Screen })
        }
    }

    if ($issues.Count -gt 0) {
        Add-DocxHeading $doc 'Fix these first' 1
        Add-DocxPara $doc 'Ranked by how badly they block people and how many screens they affect.'
        $ranked = @($confirmed | Sort-Object @{ Expression = {
                    $n = 1; foreach ($sw in $Model.SiteWide) { if ($sw.First -eq $_) { $n = $sw.Screens.Count } }
                    (Get-SevRank $_.Sev) * 10 + $n }; Descending = $true } | Select-Object -First 5)
        $rows = New-Object System.Collections.ArrayList
        [void]$rows.Add(@('Issue', 'Problem', 'Where', 'Severity'))
        foreach ($f in $ranked) {
            $where = $f.Screen.Name
            foreach ($sw in $Model.SiteWide) { if ($sw.First -eq $f) { $where = 'Every screen (' + $sw.Screens.Count + ')' } }
            [void]$rows.Add(@($f.Id, $Script:Rules[$f.Rule].Title, $where, $f.Sev))
        }
        Add-DocxTable $doc $rows.ToArray() @(1300, 4300, 3080, 1400) -Header
    }

    if ($Model.SiteWide.Count -gt 0) {
        Add-DocxPageBreak $doc
        Add-DocxHeading $doc 'Found on every screen' 1
        Add-DocxPara $doc 'These come from shared parts of the app like the header or menu. Fixing them once fixes every screen.'
        foreach ($sw in $Model.SiteWide) {
            $label = 'Every screen tested (' + $sw.Screens.Count + '), for example ' + $sw.Screens[0].Name
            Add-IssueCard $doc $sw.First $label $sw.Screens[0].Directions
        }
    }

    Add-DocxPageBreak $doc
    Add-DocxHeading $doc 'Issues by screen' 1
    foreach ($s in $Model.Screens) {
        Add-DocxHeading $doc ('Screen ' + $s.Num + '. ' + $s.Name) 2
        if ($s.Directions -and $s.Directions.Count) {
            Add-DocxPara $doc 'How to get there' -Bold -SpaceAfter 2
            Add-DocxBullets $doc $s.Directions -Numbered
        }
        if ($s.Url) { Add-DocxPara $doc ('Address ' + $s.Url) -Size 9 -Color '555555' }
        $list = @($Model.PerScreen[$s.Num])
        $real = @($list | Where-Object { $_.Rule -ne 'tool-error' })
        if ($s.BaseShot) {
            $b = Read-Image $s.BaseShot
            if ($b) { Add-DocxImage $doc $b 1280 800 ('The ' + $s.Name + ' screen at normal size') 5.0 }
        }
        if ($real.Count -eq 0) { Add-DocxPara $doc 'No automated issues found on this screen, apart from any listed under Found on Every Screen.' -Italic }
        foreach ($f in $list) {
            if ($f.Rule -eq 'tool-error') {
                Add-DocxPara $doc ('Note. The ' + $f.Params['module'] + ' test could not finish on this screen, so its results may be incomplete. Details are in the Run Log.') -Italic -Color '7A5C00'
                continue
            }
            Add-IssueCard $doc $f $s.Name $s.Directions
        }
    }

    Add-DocxPageBreak $doc
    Add-DocxHeading $doc 'Needs a person' 1
    Add-DocxPara $doc 'No tool can check these automatically. Each takes a few minutes by hand.'
    $rows = New-Object System.Collections.ArrayList
    [void]$rows.Add(@('WCAG', 'What to check'))
    foreach ($m in $Script:ManualChecks) { [void]$rows.Add(@($m[0], $m[1])) }
    Add-DocxTable $doc $rows.ToArray() @(1800, 8280) -Header

    Add-DocxHeading $doc 'Screens tested' 1
    $rows = New-Object System.Collections.ArrayList
    [void]$rows.Add(@('Screen', 'How to get there', 'Issues'))
    foreach ($s in $Model.Screens) {
        $n = @($Model.PerScreen[$s.Num] | Where-Object { $_.Rule -ne 'tool-error' }).Count
        [void]$rows.Add(@(([string]$s.Num + '. ' + $s.Name), ($s.Directions -join ' '), [string]$n))
    }
    Add-DocxTable $doc $rows.ToArray() @(3000, 5880, 1200) -Header -FontSize 10

    Add-DocxHeading $doc 'WCAG 2.2 AA scorecard' 1
    Add-DocxPara $doc 'Pass (automated) means the automated tests found nothing on the screens tested. Not tested yet means a later phase of this tool will cover it.'
    Add-DocxTable $doc $score.ToArray() @(1300, 4980, 900, 2900) -Header -FontSize 10

    $reportPath = Join-Path $Ctx.RunDir 'Accessibility Report.docx'
    Save-Docx $doc $reportPath

    # Issue list for tracking
    $csv = New-Object System.Collections.ArrayList
    foreach ($f in $issues) {
        $r = $Script:Rules[$f.Rule]
        $where = $f.Screen.Name; $dirs = $f.Screen.Directions
        foreach ($sw in $Model.SiteWide) { if ($sw.First -eq $f) { $where = 'Every screen (' + $sw.Screens.Count + ')' } }
        [void]$csv.Add([pscustomobject][ordered]@{
                'Issue ID' = $f.Id; 'Status Since Last Run' = $f.Status; 'Severity' = $f.Sev; 'Confidence' = $(if ($f.Conf -eq 'confirmed') { 'Confirmed' } else { 'Please check' })
                'Screen' = $where; 'Directions' = ($dirs -join ' '); 'Problem' = $r.Title; 'What We Found' = (Format-Template $r.What $f.Params)
                'Recommended Fix' = $r.Fix; 'Developer Note' = $f.Dev; 'WCAG Criterion' = ($r.Wcag + ' ' + $r.WcagName).Trim(); 'DOF Checklist Item' = $r.Dof
                'Screenshot File' = $(if ($f.Shot) { Split-Path $f.Shot -Leaf } else { '' })
            })
    }
    $raw = New-Object System.Collections.ArrayList
    foreach ($s in $Model.Screens) { foreach ($f in $s.Findings) { [void]$raw.Add(($s.Url + "`t" + $f.Rule + "`t" + $f.Sev + "`t" + $f.Conf + "`t" + $f.Dev)) } }
    Set-Content -LiteralPath (Join-Path $Ctx.RunDir 'findings-data.tsv') -Value $raw -Encoding UTF8
    $csvPath = Join-Path $Ctx.RunDir 'Issue List.csv'
    if ($csv.Count -gt 0) { $csv | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8 }
    else { Set-Content -LiteralPath $csvPath -Value '"Issue ID","Problem"' -Encoding UTF8 }

    # Screen reader transcripts
    $t = New-Docx ($app + ' Screen Reader Transcripts')
    Add-DocxHeading $t ($app + ' Screen Reader Transcripts') 0
    Add-DocxPara $t 'What a screen reader would announce on each screen, in reading order. Lines marked NO NAME or NO DESCRIPTION are what a blind user would hear as a blank.'
    foreach ($s in $Model.Screens) {
        Add-DocxHeading $t ('Screen ' + $s.Num + '. ' + $s.Name) 1
        $lines = @($s.Transcript)
        if ($lines.Count -eq 0) { Add-DocxPara $t 'No transcript was captured for this screen.' -Italic; continue }
        foreach ($l in $lines) {
            $color = ''
            if ($l -match 'NO NAME|NO DESCRIPTION') { $color = 'B00020' }
            Add-DocxPara $t $l -Size 10 -SpaceAfter 2 -Color $color
        }
    }
    Save-Docx $t (Join-Path $Ctx.RunDir 'Screen Reader Transcripts.docx')
    return $reportPath
}
