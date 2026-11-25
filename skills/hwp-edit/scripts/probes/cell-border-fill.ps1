# CellBorderFill on the cell holding the caret: per-side line type, width, colour, and a solid fill.
# Ledger: references/verified-api.md (CellBorderFill).
function Invoke-HwpProbe {
    param($Hwp)
    $table = $Hwp.HParameterSet.HTableCreation
    $Hwp.HAction.GetDefault('TableCreate', $table.HSet) | Out-Null
    $table.Rows = 1; $table.Cols = 1
    $table.TableProperties.TreatAsChar = 1
    $Hwp.HAction.Execute('TableCreate', $table.HSet) | Out-Null

    $set = $Hwp.HParameterSet.HCellBorderFill
    $Hwp.HAction.GetDefault('CellBorderFill', $set.HSet) | Out-Null
    # ParameterSetTable 2504 spells the left colour "BorderCorlorLeft"; give each spelling its own colour to see which applies.
    $set.HSet.SetItem('BorderColorLeft', 0x000000FF)     # red
    $set.HSet.SetItem('BorderCorlorLeft', 0x0000FF00)    # green
    foreach ($side in 'Left','Top') { $set.HSet.SetItem("BorderType$side", 1); $set.HSet.SetItem("BorderWidth$side", 1) }
    $set.HSet.SetItem('BorderColorTop', 0x00FFFFFF)
    foreach ($side in 'Right','Bottom') { $set.HSet.SetItem("BorderType$side", 1); $set.HSet.SetItem("BorderWidth$side", 9); $set.HSet.SetItem("BorderColor$side", 0x00C0C0C0) }
    $set.FillAttr.Type = 1
    $set.FillAttr.WinBrushFaceColor = 0x00ECE3E3
    $set.FillAttr.WinBrushHatchColor = 0
    $set.FillAttr.WinBrushFaceStyle = -1
    $returned = $Hwp.HAction.Execute('CellBorderFill', $set.HSet)

    $xml = Read-HwpMarkup $Hwp
    $cell = $xml.SelectSingleNode('//TABLE/ROW/CELL')
    $fill = $xml.SelectSingleNode("//BORDERFILLLIST/BORDERFILL[@Id='$($cell.GetAttribute('BorderFill'))']")
    $leftColor = [int]$fill.SelectSingleNode('./LEFTBORDER').GetAttribute('Color')
    return [ordered]@{
        executeReturned = [bool]$returned
        leftColorFrom = $(switch ($leftColor) { 0x000000FF { 'BorderColorLeft' } 0x0000FF00 { 'BorderCorlorLeft' } default { "neither ($leftColor)" } })
        borderFill = $fill.OuterXml
    }
}
