# ---------------------------------------------------------------------------
# Minimal Word (.docx) writer. Builds the file directly with built in zip
# classes, so Word does not need to be installed or open.
# ---------------------------------------------------------------------------

function New-Docx {
    param([string]$Title = 'Report')
    return [pscustomobject]@{
        Title  = $Title
        Body   = New-Object System.Text.StringBuilder
        Media  = New-Object System.Collections.ArrayList
        NextId = 1
    }
}

function ConvertTo-XmlText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $t = [regex]::Replace($Text, '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    return [System.Security.SecurityElement]::Escape($t)
}

function Get-DocxRun {
    param([string]$Text, [switch]$Bold, [string]$Color, [int]$Size = 0, [switch]$Italic, [switch]$Mono)
    $rpr = ''
    if ($Bold) { $rpr += '<w:b/>' }
    if ($Italic) { $rpr += '<w:i/>' }
    if ($Mono) { $rpr += '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>' }
    if ($Color) { $rpr += '<w:color w:val="' + $Color + '"/>' }
    if ($Size -gt 0) { $rpr += '<w:sz w:val="' + ($Size * 2) + '"/><w:szCs w:val="' + ($Size * 2) + '"/>' }
    if ($rpr) { $rpr = '<w:rPr>' + $rpr + '</w:rPr>' }
    $parts = ([string]$Text) -split "`n"
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i -gt 0) { [void]$sb.Append('<w:br/>') }
        [void]$sb.Append('<w:t xml:space="preserve">' + (ConvertTo-XmlText $parts[$i]) + '</w:t>')
    }
    return '<w:r>' + $rpr + $sb.ToString() + '</w:r>'
}

function Add-DocxHeading {
    param($Doc, [string]$Text, [int]$Level = 1)
    $style = 'Heading' + $Level
    if ($Level -eq 0) { $style = 'Title' }
    [void]$Doc.Body.Append('<w:p><w:pPr><w:pStyle w:val="' + $style + '"/></w:pPr>' + (Get-DocxRun $Text) + '</w:p>')
}

function Add-DocxPara {
    param($Doc, [string]$Text, [switch]$Bold, [string]$Color, [int]$Size = 0, [switch]$Italic, [switch]$Mono, [int]$SpaceAfter = -1, [string]$Shade)
    $ppr = ''
    if ($SpaceAfter -ge 0) { $ppr += '<w:spacing w:after="' + ($SpaceAfter * 20) + '"/>' }
    if ($Shade) { $ppr += '<w:shd w:val="clear" w:color="auto" w:fill="' + $Shade + '"/>' }
    if ($ppr) { $ppr = '<w:pPr>' + $ppr + '</w:pPr>' }
    [void]$Doc.Body.Append('<w:p>' + $ppr + (Get-DocxRun $Text -Bold:$Bold -Color $Color -Size $Size -Italic:$Italic -Mono:$Mono) + '</w:p>')
}

function Add-DocxBullets {
    param($Doc, [string[]]$Items, [switch]$Numbered)
    $n = 0
    foreach ($it in $Items) {
        $n++
        $prefix = [string][char]0x2022 + ' '
        if ($Numbered) { $prefix = "$n. " }
        [void]$Doc.Body.Append('<w:p><w:pPr><w:spacing w:after="60"/><w:ind w:left="360" w:hanging="360"/></w:pPr>' + (Get-DocxRun ($prefix + $it)) + '</w:p>')
    }
}

function Add-DocxPageBreak {
    param($Doc)
    [void]$Doc.Body.Append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
}

function Add-DocxTable {
    # Rows is an array of string arrays. First row is the header when -Header is set.
    param($Doc, $Rows, [int[]]$Widths, [switch]$Header, [string]$HeaderFill = '0A3470', [switch]$FirstColBold, [int]$FontSize = 0)
    if (-not $Rows -or $Rows.Count -eq 0) { return }
    $cols = $Rows[0].Count
    if (-not $Widths) { $w = [int](9360 / $cols); $Widths = @(); for ($i = 0; $i -lt $cols; $i++) { $Widths += $w } }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/><w:tblLayout w:type="fixed"/>')
    [void]$sb.Append('<w:tblBorders><w:top w:val="single" w:sz="4" w:color="999999"/><w:left w:val="single" w:sz="4" w:color="999999"/><w:bottom w:val="single" w:sz="4" w:color="999999"/><w:right w:val="single" w:sz="4" w:color="999999"/><w:insideH w:val="single" w:sz="4" w:color="999999"/><w:insideV w:val="single" w:sz="4" w:color="999999"/></w:tblBorders>')
    [void]$sb.Append('<w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="100" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>')
    foreach ($w in $Widths) { [void]$sb.Append('<w:gridCol w:w="' + $w + '"/>') }
    [void]$sb.Append('</w:tblGrid>')
    $r = 0
    foreach ($row in $Rows) {
        $isHead = $Header -and $r -eq 0
        [void]$sb.Append('<w:tr>')
        if ($isHead) { [void]$sb.Append('<w:trPr><w:tblHeader/></w:trPr>') }
        for ($c = 0; $c -lt $cols; $c++) {
            $text = ''
            if ($c -lt $row.Count) { $text = [string]$row[$c] }
            [void]$sb.Append('<w:tc><w:tcPr><w:tcW w:w="' + $Widths[$c] + '" w:type="dxa"/>')
            if ($isHead) { [void]$sb.Append('<w:shd w:val="clear" w:color="auto" w:fill="' + $HeaderFill + '"/>') }
            elseif ($Header -and ($r % 2 -eq 0)) { [void]$sb.Append('<w:shd w:val="clear" w:color="auto" w:fill="F5F5F5"/>') }
            [void]$sb.Append('</w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr>')
            if ($isHead) { [void]$sb.Append((Get-DocxRun $text -Bold -Color 'FFFFFF' -Size $FontSize)) }
            elseif ($FirstColBold -and $c -eq 0) { [void]$sb.Append((Get-DocxRun $text -Bold -Size $FontSize)) }
            else { [void]$sb.Append((Get-DocxRun $text -Size $FontSize)) }
            [void]$sb.Append('</w:p></w:tc>')
        }
        [void]$sb.Append('</w:tr>')
        $r++
    }
    [void]$sb.Append('</w:tbl><w:p><w:pPr><w:spacing w:after="120"/></w:pPr></w:p>')
    [void]$Doc.Body.Append($sb.ToString())
}

function Add-DocxImage {
    param($Doc, [byte[]]$Bytes, [int]$WidthPx, [int]$HeightPx, [string]$Alt = 'Screenshot', [double]$MaxInches = 6.3, [string]$Ext = 'jpeg')
    if (-not $Bytes -or $Bytes.Length -eq 0 -or $WidthPx -lt 1 -or $HeightPx -lt 1) { return }
    $n = $Doc.NextId; $Doc.NextId++
    $rid = 'rIdImg' + $n
    [void]$Doc.Media.Add([pscustomobject]@{ Id = $rid; Name = ('image' + $n + '.' + $Ext); Bytes = $Bytes })
    $maxPx = $MaxInches * 96
    $scale = 1.0
    if ($WidthPx -gt $maxPx) { $scale = $maxPx / $WidthPx }
    if ($HeightPx * $scale -gt 8.0 * 96) { $scale = (8.0 * 96) / $HeightPx }
    $cx = [long]([Math]::Round($WidthPx * $scale * 9525))
    $cy = [long]([Math]::Round($HeightPx * $scale * 9525))
    $alt = ConvertTo-XmlText $Alt
    $xml = '<w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="' + $cx + '" cy="' + $cy + '"/>' +
        '<wp:docPr id="' + $n + '" name="Picture ' + $n + '" descr="' + $alt + '"/><wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>' +
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="' + $n + '" name="image' + $n + '"/><pic:cNvPicPr/></pic:nvPicPr>' +
        '<pic:blipFill><a:blip r:embed="' + $rid + '"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="' + $cx + '" cy="' + $cy + '"/></a:xfrm>' +
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:ln w="9525"><a:solidFill><a:srgbClr val="999999"/></a:solidFill></a:ln></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>'
    [void]$Doc.Body.Append($xml)
}

function Save-Docx {
    param($Doc, [string]$Path)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ' +
          'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" ' +
          'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"'
    $document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document ' + $ns + '><w:body>' + $Doc.Body.ToString() +
        '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>'
    $styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US"/></w:rPr></w:rPrDefault>' +
        '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>' +
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>' +
        '<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:after="200"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:color w:val="0A3470"/><w:sz w:val="48"/><w:szCs w:val="48"/></w:rPr></w:style>' +
        '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="360" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:color w:val="0A3470"/><w:sz w:val="34"/><w:szCs w:val="34"/></w:rPr></w:style>' +
        '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="280" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:color w:val="0A3470"/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr></w:style>' +
        '<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="200" w:after="80"/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:b/><w:color w:val="1F1F1F"/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:style>' +
        '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:color="999999"/><w:left w:val="single" w:sz="4" w:color="999999"/><w:bottom w:val="single" w:sz="4" w:color="999999"/><w:right w:val="single" w:sz="4" w:color="999999"/><w:insideH w:val="single" w:sz="4" w:color="999999"/><w:insideV w:val="single" w:sz="4" w:color="999999"/></w:tblBorders></w:tblPr></w:style>' +
        '</w:styles>'
    $rels = New-Object System.Text.StringBuilder
    [void]$rels.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    [void]$rels.Append('<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>')
    foreach ($m in $Doc.Media) { [void]$rels.Append('<Relationship Id="' + $m.Id + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/' + $m.Name + '"/>') }
    [void]$rels.Append('</Relationships>')
    $ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>' +
        '<Default Extension="jpeg" ContentType="image/jpeg"/><Default Extension="png" ContentType="image/png"/>' +
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>' +
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>'
    $rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' +
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>'
    $now = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $core = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
        '<dc:title>' + (ConvertTo-XmlText $Doc.Title) + '</dc:title><dc:creator>A11y Tester</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">' + $now + '</dcterms:created></cp:coreProperties>'

    $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $write = {
            param($name, [byte[]]$bytes)
            $e = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
            $s = $e.Open()
            try { $s.Write($bytes, 0, $bytes.Length) } finally { $s.Dispose() }
        }
        & $write '[Content_Types].xml' $utf8.GetBytes($ct)
        & $write '_rels/.rels' $utf8.GetBytes($rootRels)
        & $write 'docProps/core.xml' $utf8.GetBytes($core)
        & $write 'word/document.xml' $utf8.GetBytes($document)
        & $write 'word/styles.xml' $utf8.GetBytes($styles)
        & $write 'word/_rels/document.xml.rels' $utf8.GetBytes($rels.ToString())
        foreach ($m in $Doc.Media) { & $write ('word/media/' + $m.Name) $m.Bytes }
    } finally { $zip.Dispose() }
}
