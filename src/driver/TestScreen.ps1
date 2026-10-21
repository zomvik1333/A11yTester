# ---------------------------------------------------------------------------
# Runs every test module against the screen currently showing in the browser.
# ---------------------------------------------------------------------------

function Write-Log {
    param([string]$Text)
    $line = (Get-Date).ToString('HH:mm:ss') + '  ' + $Text
    if ($Script:LogPath) { Add-Content -LiteralPath $Script:LogPath -Value $line -Encoding UTF8 }
}

function Write-Step {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host ('  ' + $Text) -ForegroundColor $Color
    Write-Log $Text
}

function Initialize-Bundle {
    param($Conn)
    $ok = $false
    try { $ok = Invoke-Js $Conn '!!(window.__a11y && window.__a11y.v === 3 && window.__a11y.srChecks && window.__a11y.zoomCheck)' } catch { }
    if (-not $ok) { Invoke-Js $Conn $Script:JsBundle | Out-Null }
}

function New-Finding {
    param($Raw, [string]$Phase)
    return [pscustomobject]@{
        Rule = [string](Get-Field $Raw 'rule')
        Sev = [string](Get-Field $Raw 'sev' 'Medium')
        Conf = [string](Get-Field $Raw 'conf' 'confirmed')
        Params = (Get-Field $Raw 'params' @{})
        Dev = [string](Get-Field $Raw 'dev' '')
        Sig = [string](Get-Field $Raw 'sig' '')
        Mark = (Get-Field $Raw 'mark' 0)
        TabNumbers = [bool](Get-Field $Raw 'tabNumbers' $false)
        Phase = $Phase
        Shot = $null; ShotW = 0; ShotH = 0
        Shot2 = $null; Shot2W = 0; Shot2H = 0
        Screen = $null; Id = ''; Hash = ''; Status = ''
    }
}

function Save-Shot {
    param($Conn, $Ctx, [string]$Name, [int]$W, [int]$H)
    if ($Ctx.ShotCount -ge $Ctx.MaxShots) { return $null }
    $Ctx.ShotCount++
    $b64 = Get-Screenshot $Conn $null 'jpeg' 65
    if (-not $b64) { return $null }
    $path = Join-Path $Ctx.ShotDir ($Name + '.jpg')
    [System.IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($b64))
    return $path
}

function Add-Findings {
    # Turns raw findings from the page into report findings, with a marked screenshot for each.
    param($Conn, $Ctx, $Screen, $RawList, [string]$Phase, [int]$W, [int]$H, [string]$FallbackShot, [switch]$MergeZoom)
    if (-not $RawList) { return }
    foreach ($raw in $RawList) {
        $f = New-Finding $raw $Phase
        $f.Screen = $Screen
        if ($MergeZoom -and $f.Sig) {
            $kind = ''
            if ($f.Rule -match 'clip') { $kind = 'clip' } elseif ($f.Rule -match 'overlap') { $kind = 'overlap' }
            if ($kind) {
                $prev = @($Screen.Findings | Where-Object { $_.Sig -eq $f.Sig -and $_.Rule -match $kind -and $_.Phase -ne 'tool' }) | Select-Object -First 1
                if ($prev) { $prev.Phase = $prev.Phase + ', also ' + $Phase.ToLower(); continue }
            }
        }
        if ($f.TabNumbers) {
            Invoke-Js $Conn '__a11y.showTabNumbers()' | Out-Null
            Start-Sleep -Milliseconds 150
            $p = Save-Shot $Conn $Ctx ('s{0:D3}-taborder' -f $Screen.Num) $W $H
            if ($p) { $f.Shot = $p; $f.ShotW = $W; $f.ShotH = $H }
            Invoke-Js $Conn '__a11y.clearOverlays()' | Out-Null
        } elseif ($f.Mark) {
            $n = Invoke-Js $Conn ('__a11y.showMarks([' + [int]$f.Mark + '])')
            if ($n -gt 0) {
                Start-Sleep -Milliseconds 150
                $Screen.ShotSeq++
                $p = Save-Shot $Conn $Ctx ('s{0:D3}-{1:D2}' -f $Screen.Num, $Screen.ShotSeq) $W $H
                if ($p) { $f.Shot = $p; $f.ShotW = $W; $f.ShotH = $H }
            }
            Invoke-Js $Conn '__a11y.clearOverlays()' | Out-Null
        }
        if (-not $f.Shot -and $FallbackShot) { $f.Shot = $FallbackShot; $f.ShotW = $W; $f.ShotH = $H }
        [void]$Screen.Findings.Add($f)
    }
}

function Add-ToolError {
    param($Screen, [string]$Module, $Err)
    $msg = [string]$Err
    $where = ''
    if ($Err -and $Err.Exception) { $msg = $Err.Exception.Message; $where = [string]$Err.ScriptStackTrace }
    Write-Log ("ERROR in $Module on " + $Screen.Name + ' ' + $msg + ' ' + ($where -replace "`r?`n", ' | '))
    $f = New-Finding @{ rule = 'tool-error'; sev = 'Low'; conf = 'check'; params = @{ module = $Module; detail = '' } } 'tool'
    $f.Screen = $Screen
    $f.Dev = $msg
    [void]$Screen.Findings.Add($f)
}

function Invoke-ZoomTests {
    param($Conn, $Ctx, $Screen)
    Write-Step 'Zoom and text spacing'
    Set-Viewport $Conn 1280 800
    Invoke-Js $Conn '__a11y.zoomBaseline()' | Out-Null

    Set-Viewport $Conn 320 640 900
    Invoke-Js $Conn '__a11y.settle(300, 2500)' -Await | Out-Null
    $raw = Invoke-Js $Conn "__a11y.zoomCheck('reflow')"
    $fallback = $null
    if ($raw -and @($raw).Count -gt 0) {
        Invoke-Js $Conn 'window.scrollTo(0,0)' | Out-Null
        $fallback = Save-Shot $Conn $Ctx ('s{0:D3}-zoom400' -f $Screen.Num) 320 640
    }
    Add-Findings $Conn $Ctx $Screen $raw 'At 400% zoom' 320 640 $fallback

    Set-Viewport $Conn 640 400 700
    Invoke-Js $Conn '__a11y.settle(300, 2500)' -Await | Out-Null
    $raw = Invoke-Js $Conn "__a11y.zoomCheck('resize')"
    Add-Findings $Conn $Ctx $Screen $raw 'At 200% zoom' 640 400 $null -MergeZoom

    Set-Viewport $Conn 1280 800 500
    Invoke-Js $Conn '__a11y.spacingOn()' | Out-Null
    Start-Sleep -Milliseconds 400
    $raw = Invoke-Js $Conn "__a11y.zoomCheck('spacing')"
    Add-Findings $Conn $Ctx $Screen $raw 'With wider text spacing' 1280 800 $null -MergeZoom
    Invoke-Js $Conn '__a11y.spacingOff()' | Out-Null
}

function Invoke-KeyboardTests {
    param($Conn, $Ctx, $Screen)
    Write-Step 'Keyboard only'
    Set-Viewport $Conn 1280 800 400
    Invoke-Js $Conn '__a11y.kbStart()' | Out-Null
    $stops = 0; $none = 0; $trap = $null
    for ($i = 0; $i -lt $Ctx.MaxTabs; $i++) {
        Send-Key $Conn 'Tab' 9
        Start-Sleep -Milliseconds 35
        $r = Invoke-Js $Conn ('__a11y.kbStep(' + $i + ')')
        if (Get-Field $r 'none' $false) {
            $none++
            if (($stops -gt 0 -and $none -ge 2) -or $none -ge 3) { break }
            continue
        }
        $none = 0
        if (Get-Field $r 'ours' $false) { continue }
        if (Get-Field $r 'repeat' $false) {
            $first = [int](Get-Field $r 'first' 0)
            if ($first -eq 0) { break }
            # Focus is cycling inside part of the page. Try to escape.
            Send-Key $Conn 'Escape' 27
            Start-Sleep -Milliseconds 150
            $escaped = $false
            for ($k = 0; $k -lt 6; $k++) {
                Send-Key $Conn 'Tab' 9
                Start-Sleep -Milliseconds 35
                $r2 = Invoke-Js $Conn ('__a11y.kbStep(' + ($i + $k + 1) + ')')
                if ((Get-Field $r2 'none' $false) -or -not (Get-Field $r2 'repeat' $false)) { $escaped = $true; break }
            }
            if (-not $escaped) { $trap = @{ name = (Get-Field $r 'label' 'an item'); count = ($stops - $first) } }
            break
        }
        $stops++
    }
    $Screen.TabStops = $stops
    $res = Invoke-Js $Conn '__a11y.kbAnalyze()'
    Add-Findings $Conn $Ctx $Screen (Get-Field $res 'findings' @()) 'Keyboard' 1280 800 $null
    if ($trap) {
        foreach ($u in @($Screen.Findings | Where-Object { $_.Rule -eq 'kb-unreachable' })) { $Screen.Findings.Remove($u) }
        $f = New-Finding @{ rule = 'kb-trap'; sev = 'High'; conf = 'confirmed'; params = $trap } 'Keyboard'
        $f.Screen = $Screen
        $f.Dev = 'Focus cycles inside one area and Esc does not release it.'
        [void]$Screen.Findings.Add($f)
    }

    # Focus visible. Screenshot each stop focused and not focused, then compare.
    $n = [int](Invoke-Js $Conn '__a11y.fvPrep()')
    $bad = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $n; $i++) {
        $clip = Invoke-Js $Conn ('__a11y.fvFocus(' + $i + ')')
        if (-not $clip) { continue }
        Start-Sleep -Milliseconds 30
        $a = Get-Screenshot $Conn $clip 'png'
        Invoke-Js $Conn ('__a11y.fvBlur(' + $i + ')') | Out-Null
        Start-Sleep -Milliseconds 30
        $b = Get-Screenshot $Conn $clip 'png'
        if ($a -eq $b) { [void]$bad.Add($i); continue }
        $diff = Invoke-Js $Conn ('__a11y.fvCompare(' + (ConvertTo-JsString $a) + ',' + (ConvertTo-JsString $b) + ')') -Await
        if ([int]$diff -lt 4) { [void]$bad.Add($i) }
    }
    $raw = Invoke-Js $Conn ('__a11y.fvResult([' + ($bad -join ',') + '])')
    Add-Findings $Conn $Ctx $Screen $raw 'Keyboard' 1280 800 $null
}

function Invoke-ScreenReaderTests {
    param($Conn, $Ctx, $Screen)
    Write-Step 'Screen reader'
    Set-Viewport $Conn 1280 800 400
    $rawAx = Invoke-Cdp $Conn 'Accessibility.getFullAXTree' '{}' 90 -Raw
    $want = Invoke-Js $Conn ('__a11y.setAx(' + $rawAx + ')') -TimeoutSec 90
    $rawAx = $null
    $ids = @($want | Where-Object { $_ })
    if ($ids.Count -gt 0) {
        Invoke-Cdp $Conn 'DOM.getDocument' '{"depth":0}' | Out-Null
        $pushed = Invoke-Cdp $Conn 'DOM.pushNodesByBackendIdsToFrontend' ('{"backendNodeIds":[' + ($ids -join ',') + ']}')
        $nodeIds = @(Get-Field $pushed 'nodeIds' @())
        for ($i = 0; $i -lt $nodeIds.Count -and $i -lt $ids.Count; $i++) {
            $nid = [int]$nodeIds[$i]
            if ($nid -le 0) { continue }
            try { Invoke-Cdp $Conn 'DOM.setAttributeValue' ('{"nodeId":' + $nid + ',"name":"data-a11y-ax","value":"' + [int]$ids[$i] + '"}') 10 | Out-Null } catch { }
        }
    }
    $raw = Invoke-Js $Conn '__a11y.srChecks()'
    Add-Findings $Conn $Ctx $Screen $raw 'Screen reader' 1280 800 $null
    $Screen.Transcript = @(Invoke-Js $Conn '__a11y.transcript()')
}

function Invoke-ScreenTest {
    param($Conn, $Ctx, [string[]]$Directions)
    try { Invoke-Js $Conn 'window.__a11yTb && __a11yTb.hide()' | Out-Null } catch { }
    try { Invoke-Js $Conn '(window.__a11y && __a11y.settle) ? __a11y.settle(500, 6000) : 0' -Await -TimeoutSec 15 | Out-Null } catch { }
    Initialize-Bundle $Conn
    Invoke-Js $Conn '__a11y.settle(500, 6000)' -Await -TimeoutSec 15 | Out-Null
    $info = Invoke-Js $Conn '__a11y.screenInfo()'
    $Ctx.ScreenNum++
    $screen = [pscustomobject]@{
        Num = $Ctx.ScreenNum
        Name = [string](Get-Field $info 'name' 'Untitled screen')
        Title = [string](Get-Field $info 'title' '')
        Url = [string](Get-Field $info 'url' '')
        Key = ([string](Get-Field $info 'path' '') + '|' + [string](Get-Field $info 'name' '')).ToLower()
        Directions = $Directions
        Findings = New-Object System.Collections.ArrayList
        Transcript = @()
        BaseShot = $null
        TabStops = 0
        ShotSeq = 0
        Seconds = 0
    }
    Write-Host ''
    Write-Host ('Testing screen ' + $screen.Num + '. ' + $screen.Name) -ForegroundColor Cyan
    Write-Log ('Screen ' + $screen.Num + ' ' + $screen.Name + ' ' + $screen.Url)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    Set-Viewport $Conn 1280 800 500
    Invoke-Js $Conn 'window.scrollTo(0,0)' | Out-Null
    $Ctx.ShotCount = [Math]::Max(0, $Ctx.ShotCount - 0)
    $screen.BaseShot = Save-Shot $Conn $Ctx ('s{0:D3}-screen' -f $screen.Num) 1280 800

    foreach ($m in @('Zoom', 'Keyboard', 'ScreenReader')) {
        if ($Ctx.Skip -contains $m) { continue }
        try {
            Initialize-Bundle $Conn
            switch ($m) {
                'Zoom' { Invoke-ZoomTests $Conn $Ctx $screen }
                'Keyboard' { Invoke-KeyboardTests $Conn $Ctx $screen }
                'ScreenReader' { Invoke-ScreenReaderTests $Conn $Ctx $screen }
            }
        } catch {
            Add-ToolError $screen $m $_
            Write-Step ("The $m test hit a problem on this screen and was skipped. Details are in the Run Log.") 'Yellow'
        }
    }
    try { Invoke-Js $Conn 'window.__a11y && __a11y.cleanup()' | Out-Null } catch { }
    Clear-Viewport $Conn
    $sw.Stop()
    $screen.Seconds = [int]$sw.Elapsed.TotalSeconds
    $real = @($screen.Findings | Where-Object { $_.Rule -ne 'tool-error' }).Count
    Write-Step ("Done in {0} seconds. Found {1} possible issue(s)." -f $screen.Seconds, $real) 'Green'
    try { Invoke-Js $Conn ('window.__a11yTb && __a11yTb.show(' + (ConvertTo-JsString ('Tested "' + $screen.Name + '". Found ' + $real + ' possible issue(s). Go to the next screen or click Done.')) + ')') | Out-Null } catch { }
    return $screen
}
