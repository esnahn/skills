# TablePropertyDialog (ShapeObject.ShapeTableCell): the margins of the cell holding the caret.
# A new cell keeps its own 510/141 margins even when TableProperties.CellMargin* sets the table default.
# Ledger: references/verified-api.md (TablePropertyDialog).
function Invoke-HwpProbe {
    param($Hwp)
    $table = $Hwp.HParameterSet.HTableCreation
    $Hwp.HAction.GetDefault('TableCreate', $table.HSet) | Out-Null
    $table.Rows = 2; $table.Cols = 1
    $table.TableProperties.TreatAsChar = 1
    $Hwp.HAction.Execute('TableCreate', $table.HSet) | Out-Null
    function Get-CellMargins {
        @((Read-HwpMarkup $Hwp).SelectNodes('//TABLE/ROW/CELL') | ForEach-Object { "HasMargin=$($_.GetAttribute('HasMargin')) " + $_.SelectSingleNode('./CELLMARGIN').OuterXml })
    }
    $before = Get-CellMargins

    $set = $Hwp.HParameterSet.HShapeObject
    $Hwp.HAction.GetDefault('TablePropertyDialog', $set.HSet) | Out-Null
    # Reading items back goes through the wrapper's properties; HSet exposes no Item method to PowerShell,
    # and the HShapeObject wrapper has no ShapeType property, so only the cell defaults are read.
    $defaults = [ordered]@{
        HasMargin = $set.ShapeTableCell.HasMargin
        MarginLeft = $set.ShapeTableCell.MarginLeft
        MarginTop = $set.ShapeTableCell.MarginTop
    }
    $set.HSet.SetItem('ShapeType', 3)
    $set.HSet.SetItem('ShapeCellSize', 0)
    $set.ShapeTableCell.HasMargin = 0
    $set.ShapeTableCell.MarginLeft = 141
    $set.ShapeTableCell.MarginRight = 141
    $set.ShapeTableCell.MarginTop = 141
    $set.ShapeTableCell.MarginBottom = 141
    $returned = $Hwp.HAction.Execute('TablePropertyDialog', $set.HSet)
    $marginsAfter = @(Get-CellMargins)

    # The cell option "한 줄로 입력" through ShapeTableCell.LineWrap (ListProperties): where does it land?
    $lineWrap = [ordered]@{}
    foreach ($value in 1, 2) {
        if ($value -eq 2) { $Hwp.HAction.Run('TableLowerCell') | Out-Null }
        $cell = $Hwp.HParameterSet.HShapeObject
        $Hwp.HAction.GetDefault('TablePropertyDialog', $cell.HSet) | Out-Null
        $cell.HSet.SetItem('ShapeType', 3)
        $cell.ShapeTableCell.LineWrap = $value
        $Hwp.HAction.Execute('TablePropertyDialog', $cell.HSet) | Out-Null
        $text = $Hwp.HParameterSet.HInsertText
        $Hwp.HAction.GetDefault('InsertText', $text.HSet) | Out-Null
        $text.Text = "wrap $value"
        $Hwp.HAction.Execute('InsertText', $text.HSet) | Out-Null
    }
    $xml = Read-HwpMarkup $Hwp
    foreach ($node in $xml.SelectNodes('//TABLE/ROW/CELL')) {
        $list = $node.SelectSingleNode('./PARALIST'); $paragraph = $list.SelectSingleNode('./P')
        $lineWrap[(-join @($paragraph.SelectNodes('./TEXT/CHAR') | ForEach-Object { $_.InnerText }))] = [ordered]@{
            paraList = $list.GetAttribute('LineWrap')
            paraShape = $xml.SelectSingleNode("//PARASHAPE[@Id='$($paragraph.GetAttribute('ParaShape'))']").GetAttribute('LineWrap')
        }
    }
    return [ordered]@{
        lineWrapViaCell = $lineWrap
        executeReturned = [bool]$returned
        defaultsInCell = $defaults
        cellMarginsBefore = $before
        cellMarginsAfter = $marginsAfter
    }
}
