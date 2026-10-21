# ---------------------------------------------------------------------------
# JSON helpers and the connection to Edge (Chrome DevTools Protocol).
# Uses only classes built into Windows PowerShell 5.1. No downloads.
# ---------------------------------------------------------------------------

$Script:JsonSerializer = $null

function ConvertFrom-JsonFast {
    param([string]$Text)
    if ($PSVersionTable.PSVersion.Major -le 5) {
        if (-not $Script:JsonSerializer) {
            Add-Type -AssemblyName System.Web.Extensions
            $Script:JsonSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
            $Script:JsonSerializer.MaxJsonLength = [int]::MaxValue
            $Script:JsonSerializer.RecursionLimit = 1000
        }
        return ,$Script:JsonSerializer.DeserializeObject($Text)
    }
    return ,(ConvertFrom-Json -InputObject $Text -AsHashtable -Depth 1000 -NoEnumerate)
}

function ConvertTo-JsString {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return 'null' }
    $s = $Text.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t')
    $s = [regex]::Replace($s, '[\x00-\x1f\u2028\u2029]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
    return '"' + $s + '"'
}

function Get-Field {
    # Safe lookup on dictionaries returned by ConvertFrom-JsonFast
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        $v = $Object[$Name]
        if ($null -eq $v) { return $Default }
        return $v
    }
    return $Default
}

function Get-LocalJson {
    param([string]$Url)
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Proxy = $null
    $req.Timeout = 5000
    $resp = $req.GetResponse()
    try {
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $text = $sr.ReadToEnd()
    } finally { $resp.Close() }
    return ,(ConvertFrom-JsonFast $text)
}

function New-CdpConnection {
    param([string]$WsUrl)
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    try { $ws.Options.Proxy = New-Object System.Net.WebProxy } catch { }
    $ws.Options.KeepAliveInterval = [TimeSpan]::FromSeconds(20)
    [void]$ws.ConnectAsync([Uri]$WsUrl, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()
    return [pscustomobject]@{
        Ws      = $ws
        NextId  = 0
        Buffer  = New-Object byte[] 1048576
        Stream  = New-Object System.IO.MemoryStream
        Pending = $null
        Events  = New-Object System.Collections.ArrayList
    }
}

function Close-CdpConnection {
    param($Conn)
    if (-not $Conn) { return }
    try {
        if ($Conn.Ws.State -eq 'Open') {
            $Conn.Ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [System.Threading.CancellationToken]::None).Wait(2000) | Out-Null
        }
    } catch { }
    try { $Conn.Ws.Dispose() } catch { }
}

function Send-CdpText {
    param($Conn, [string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $seg = New-Object 'System.ArraySegment[byte]' -ArgumentList @(, $bytes)
    [void]$Conn.Ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

function Receive-CdpText {
    # Returns one whole message as text, or $null if nothing arrived in time.
    param($Conn, [int]$TimeoutMs)
    while ($true) {
        if (-not $Conn.Pending) {
            $seg = New-Object 'System.ArraySegment[byte]' -ArgumentList @(, $Conn.Buffer)
            $Conn.Pending = $Conn.Ws.ReceiveAsync($seg, [System.Threading.CancellationToken]::None)
        }
        if (-not $Conn.Pending.Wait($TimeoutMs)) { return $null }
        $r = $Conn.Pending.Result
        $Conn.Pending = $null
        if ($r.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { throw 'The browser window was closed.' }
        $Conn.Stream.Write($Conn.Buffer, 0, $r.Count)
        if ($r.EndOfMessage) {
            $text = [System.Text.Encoding]::UTF8.GetString($Conn.Stream.ToArray())
            $Conn.Stream.SetLength(0)
            return $text
        }
    }
}

function Invoke-Cdp {
    param($Conn, [string]$Method, [string]$ParamsJson = '{}', [int]$TimeoutSec = 60, [switch]$Raw)
    $Conn.NextId++
    $id = $Conn.NextId
    Send-CdpText $Conn ('{"id":' + $id + ',"method":"' + $Method + '","params":' + $ParamsJson + '}')
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    while ($true) {
        $left = [int][Math]::Max(1, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
        $text = Receive-CdpText $Conn ([Math]::Min($left, 1000))
        if ($null -eq $text) {
            if ([DateTime]::UtcNow -ge $deadline) { throw "The browser did not answer $Method in time." }
            continue
        }
        if ($text -match '^\{"id":(\d+)') {
            if ([int]$Matches[1] -ne $id) { continue }
            if ($text -match '^\{"id":\d+,"error":') {
                $msg = ConvertFrom-JsonFast $text
                throw ("Browser error on {0}. {1}" -f $Method, $msg['error']['message'])
            }
            if ($Raw) { return $text }
            $msg = ConvertFrom-JsonFast $text
            return ,(Get-Field $msg 'result' @{})
        }
        [void]$Conn.Events.Add($text)
        if ($Conn.Events.Count -gt 400) { $Conn.Events.RemoveRange(0, 200) }
    }
}

function Invoke-Js {
    param($Conn, [string]$Expr, [switch]$Await, [int]$TimeoutSec = 60)
    $aw = 'false'
    if ($Await) { $aw = 'true' }
    $p = '{"expression":' + (ConvertTo-JsString $Expr) + ',"returnByValue":true,"awaitPromise":' + $aw + '}'
    $r = Invoke-Cdp $Conn 'Runtime.evaluate' $p $TimeoutSec
    $ex = Get-Field $r 'exceptionDetails'
    if ($ex) {
        $m = Get-Field $ex 'text' 'error'
        $exo = Get-Field $ex 'exception'
        $d = Get-Field $exo 'description'
        if ($d) { $m = $d }
        throw "Page script error. $m"
    }
    $res = Get-Field $r 'result'
    return (Get-Field $res 'value')
}

function Send-Key {
    param($Conn, [string]$Key, [int]$Code, [switch]$Shift)
    $mods = 0
    if ($Shift) { $mods = 8 }
    $base = '"key":"' + $Key + '","code":"' + $Key + '","windowsVirtualKeyCode":' + $Code + ',"nativeVirtualKeyCode":' + $Code + ',"modifiers":' + $mods
    Invoke-Cdp $Conn 'Input.dispatchKeyEvent' ('{"type":"rawKeyDown",' + $base + '}') | Out-Null
    Invoke-Cdp $Conn 'Input.dispatchKeyEvent' ('{"type":"keyUp",' + $base + '}') | Out-Null
}

function Set-Viewport {
    param($Conn, [int]$Width, [int]$Height, [int]$SettleMs = 700)
    Invoke-Cdp $Conn 'Emulation.setDeviceMetricsOverride' ('{"width":' + $Width + ',"height":' + $Height + ',"deviceScaleFactor":1,"mobile":false}') | Out-Null
    Start-Sleep -Milliseconds $SettleMs
}

function Clear-Viewport {
    param($Conn)
    try { Invoke-Cdp $Conn 'Emulation.clearDeviceMetricsOverride' | Out-Null } catch { }
}

function Get-Screenshot {
    # Returns base64 text. Clip is in page coordinates.
    param($Conn, $Clip = $null, [string]$Format = 'jpeg', [int]$Quality = 70)
    $p = '{"format":"' + $Format + '"'
    if ($Format -eq 'jpeg') { $p += ',"quality":' + $Quality }
    if ($Clip) {
        $p += ',"clip":{"x":' + [int](Get-Field $Clip 'x' 0) + ',"y":' + [int](Get-Field $Clip 'y' 0) + ',"width":' + [int](Get-Field $Clip 'w' 1) + ',"height":' + [int](Get-Field $Clip 'h' 1) + ',"scale":1},"captureBeyondViewport":true'
    } else {
        $p += ',"captureBeyondViewport":false'
    }
    $p += '}'
    $r = Invoke-Cdp $Conn 'Page.captureScreenshot' $p 30
    return [string](Get-Field $r 'data' '')
}
