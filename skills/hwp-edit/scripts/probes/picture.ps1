# InsertPicture: argument count, returned control, and setting the exact size through ctrl.Properties.
# Ledger: references/verified-api.md (InsertPicture).
function Invoke-HwpProbe {
    param($Hwp)
    Add-Type -AssemblyName System.Drawing
    $png = Join-Path ([IO.Path]::GetTempPath()) ('hwp-probe-' + [Guid]::NewGuid().ToString('N') + '.png')
    $bitmap = [Drawing.Bitmap]::new(200, 50); $g = [Drawing.Graphics]::FromImage($bitmap); $g.Clear([Drawing.Color]::SteelBlue); $g.Dispose()
    $bitmap.Save($png, [Drawing.Imaging.ImageFormat]::Png); $bitmap.Dispose()
    $out = [ordered]@{}
    try {
        try { $Hwp.InsertPicture($png, $true, 0, $false, $false, 0) | Out-Null; $out.sixArguments = 'accepted' } catch { $out.sixArguments = $_.Exception.Message }
        $ctrl = $Hwp.InsertPicture($png, $true, 0, $false, $false, 0, 0, 0)
        $out.ctrlId = [string]$ctrl.CtrlID
        $picture = @((Read-HwpMarkup $Hwp).SelectNodes('//PICTURE'))[-1]
        $out.realSize = $picture.SelectSingleNode('./SHAPEOBJECT/SIZE').OuterXml
        $props = $ctrl.Properties
        $props.SetItem('Width', 10528); $props.SetItem('Height', 2869); $props.SetItem('TreatAsChar', 1)
        foreach ($side in 'Left','Right','Top','Bottom') { $props.SetItem("OutsideMargin$side", 0) }
        $ctrl.Properties = $props
        $picture = @((Read-HwpMarkup $Hwp).SelectNodes('//PICTURE'))[-1]
        $component = $picture.SelectSingleNode('./SHAPECOMPONENT')
        $out.afterProperties = [ordered]@{
            size = $picture.SelectSingleNode('./SHAPEOBJECT/SIZE').OuterXml
            treatAsChar = $picture.SelectSingleNode('./SHAPEOBJECT/POSITION').GetAttribute('TreatAsChar')
            originalSize = "$($component.GetAttribute('OriWidth'))x$($component.GetAttribute('OriHeight'))"
            imageDim = $picture.SelectSingleNode('./IMAGEDIM').OuterXml
        }
    } finally { Remove-Item -LiteralPath $png -ErrorAction SilentlyContinue }
    return $out
}
