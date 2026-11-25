# TableCreate (TableCreation) as a character-like table with set column widths, row heights and margins;
# moving between cells and leaving the table. Ledger: references/verified-api.md (TableCreate).
function Invoke-HwpProbe {
    param($Hwp)
    function Add-ProbeText([string]$Text) {
        $set = $Hwp.HParameterSet.HInsertText
        $Hwp.HAction.GetDefault('InsertText', $set.HSet) | Out-Null
        $set.Text = $Text
        $Hwp.HAction.Execute('InsertText', $set.HSet) | Out-Null
    }
    # Arrays need the action-object route: the HParameterSet.HTableCreation wrapper cannot create them from PowerShell.
    $action = $Hwp.CreateAction('TableCreate')
    $set = $action.CreateSet()
    $action.GetDefault($set) | Out-Null
    $set.SetItem('Rows', 2)
    $set.SetItem('Cols', 1)
    $set.SetItem('WidthType', 2)
    $set.SetItem('HeightType', 1)
    $columns = $set.CreateItemArray('ColWidth', 1)
    $columns.SetItem(0, 30000)
    $rows = $set.CreateItemArray('RowHeight', 2)
    $rows.SetItem(0, 2000)
    $rows.SetItem(1, 3000)
    $table = $set.CreateItemSet('TableProperties', 'Table')
    $table.SetItem('TreatAsChar', 1)
    foreach ($side in 'Left','Right','Top','Bottom') {
        $table.SetItem("CellMargin$side", 141)
        $table.SetItem("OutsideMargin$side", 283)
    }
    $created = $action.Execute($set)

    Add-ProbeText 'cell one'
    $lower = $Hwp.HAction.Run('TableLowerCell')
    Add-ProbeText 'cell two'
    $end = $Hwp.HAction.Run('MoveDocEnd')
    Add-ProbeText 'after table'
    $Hwp.HAction.Run('BreakPara') | Out-Null
    Add-ProbeText 'next paragraph'

    $xml = Read-HwpMarkup $Hwp
    $node = $xml.SelectSingleNode('//TABLE')

    # A second table asking for a different outside margin, then a correction through TablePropertyDialog.
    $Hwp.HAction.Run('BreakPara') | Out-Null
    $second = $Hwp.CreateAction('TableCreate')
    $secondSet = $second.CreateSet()
    $second.GetDefault($secondSet) | Out-Null
    $secondSet.SetItem('Rows', 1); $secondSet.SetItem('Cols', 1)
    $secondTable = $secondSet.CreateItemSet('TableProperties', 'Table')
    $secondTable.SetItem('TreatAsChar', 1)
    foreach ($side in 'Left','Right','Top','Bottom') { $secondTable.SetItem("OutsideMargin$side", 140) }
    $second.Execute($secondSet) | Out-Null
    $secondAsCreated = @((Read-HwpMarkup $Hwp).SelectNodes('//TABLE'))[1].SelectSingleNode('./SHAPEOBJECT/OUTSIDEMARGIN').OuterXml
    $shape = $Hwp.HParameterSet.HShapeObject
    $Hwp.HAction.GetDefault('TablePropertyDialog', $shape.HSet) | Out-Null
    foreach ($side in 'Left','Right','Top','Bottom') { $shape.HSet.SetItem("OutsideMargin$side", 567) }
    $corrected = $Hwp.HAction.Execute('TablePropertyDialog', $shape.HSet)
    $secondAfterDialog = @((Read-HwpMarkup $Hwp).SelectNodes('//TABLE'))[1].SelectSingleNode('./SHAPEOBJECT/OUTSIDEMARGIN').OuterXml

    return [ordered]@{
        secondTable = [ordered]@{ requested = 140; asCreated = $secondAsCreated; dialogReturned = [bool]$corrected; dialogRequested = 567; afterDialog = $secondAfterDialog }
        executeReturned = [ordered]@{ TableCreate = [bool]$created; TableLowerCell = [bool]$lower; MoveDocEnd = [bool]$end }
        set = [ordered]@{ colWidth = 30000; rowHeights = @(2000, 3000); cellMargin = 141; outsideMargin = 283 }
        treatAsChar = $node.SelectSingleNode('./SHAPEOBJECT/POSITION').GetAttribute('TreatAsChar')
        size = $node.SelectSingleNode('./SHAPEOBJECT/SIZE').OuterXml
        outsideMargin = $node.SelectSingleNode('./SHAPEOBJECT/OUTSIDEMARGIN').OuterXml
        insideMargin = $node.SelectSingleNode('./INSIDEMARGIN').OuterXml
        cells = @($node.SelectNodes('./ROW/CELL') | ForEach-Object {
            [ordered]@{ width = $_.GetAttribute('Width'); height = $_.GetAttribute('Height'); cellMargin = $_.SelectSingleNode('./CELLMARGIN').OuterXml; text = (-join @($_.SelectNodes('.//CHAR') | ForEach-Object { $_.InnerText })) }
        })
        topLevelParagraphs = @($xml.SelectNodes('//BODY/SECTION/P') | ForEach-Object {
            [ordered]@{ hasTable = ($null -ne $_.SelectSingleNode('.//TABLE')); ownText = (-join @($_.SelectNodes('./TEXT/CHAR') | ForEach-Object { $_.InnerText })) }
        })
    }
}
