# Cell navigation, merging, cell names, and row deletion on a 3x3 table.
# Ledger: references/verified-api.md (Cell navigation and merging; SetCurFieldName; TableDeleteRow).
function Invoke-HwpProbe {
    param($Hwp)
    function Add-ProbeText([string]$Text) { $s = $Hwp.HParameterSet.HInsertText; $Hwp.HAction.GetDefault('InsertText', $s.HSet) | Out-Null; $s.Text = $Text; $Hwp.HAction.Execute('InsertText', $s.HSet) | Out-Null }
    function Get-Cells { @((Read-HwpMarkup $Hwp).SelectNodes('//TABLE/ROW/CELL') | ForEach-Object { "r$($_.GetAttribute('RowAddr'))c$($_.GetAttribute('ColAddr')) $($_.GetAttribute('RowSpan'))x$($_.GetAttribute('ColSpan')) [$($_.GetAttribute('Name'))] " + (-join @($_.SelectNodes('.//CHAR') | ForEach-Object { $_.InnerText })) }) }
    function Move-Start { [void]$Hwp.HAction.Run('TableColPageUp'); [void]$Hwp.HAction.Run('TableColBegin') }
    $create = $Hwp.HParameterSet.HTableCreation
    $Hwp.HAction.GetDefault('TableCreate', $create.HSet) | Out-Null
    $create.Rows = 3; $create.Cols = 3; $create.TableProperties.TreatAsChar = 1
    $Hwp.HAction.Execute('TableCreate', $create.HSet) | Out-Null
    $out = [ordered]@{}

    # Merge column 1 rows 0-2 while empty: block, extend, move, merge.
    Move-Start; [void]$Hwp.HAction.Run('TableRightCell')
    $out.mergeReturns = @([bool]$Hwp.HAction.Run('TableCellBlock'), [bool]$Hwp.HAction.Run('TableCellBlockExtend'), [bool]$Hwp.HAction.Run('TableLowerCell'), [bool]$Hwp.HAction.Run('TableLowerCell'), [bool]$Hwp.HAction.Run('TableMergeCell'))
    [void]$Hwp.HAction.Run('Cancel')
    $out.setCurFieldName = [bool]$Hwp.SetCurFieldName('merged', 1, '', '')

    # Walk with TableRightCell from the first cell, numbering each visit.
    Move-Start
    $returns = @()
    for ($i = 0; $i -lt 9; $i++) { Add-ProbeText "v$i;"; $r = [bool]$Hwp.HAction.Run('TableRightCell'); $returns += $r; if (-not $r) { break } }
    $out.rightCellReturns = $returns
    $out.cellsAfterWalk = Get-Cells
    $out.fieldList = [string]$Hwp.GetFieldList(1, 1)

    # Row deletion: with a cell block selected, then with the caret only.
    Move-Start; [void]$Hwp.HAction.Run('TableLowerCell'); [void]$Hwp.HAction.Run('TableLowerCell')
    [void]$Hwp.HAction.Run('TableCellBlock')
    $out.deleteRowWithBlock = [bool]$Hwp.HAction.Run('TableDeleteRow')
    [void]$Hwp.HAction.Run('Cancel')
    $out.deleteRowCaret = [bool]$Hwp.HAction.Run('TableDeleteRow')
    $out.cellsAfterDelete = Get-Cells
    $out.rowCount = (Read-HwpMarkup $Hwp).SelectSingleNode('//TABLE').GetAttribute('RowCount')

    # A block extended over two rows next to a merged cell, then TableDeleteRow.
    [void]$Hwp.HAction.Run('MoveDocEnd')
    $Hwp.HAction.GetDefault('TableCreate', $create.HSet) | Out-Null
    $create.Rows = 4; $create.Cols = 2; $create.TableProperties.TreatAsChar = 1
    $Hwp.HAction.Execute('TableCreate', $create.HSet) | Out-Null
    Move-Start; [void]$Hwp.HAction.Run('TableLowerCell'); [void]$Hwp.HAction.Run('TableLowerCell')
    [void]$Hwp.HAction.Run('TableCellBlock'); [void]$Hwp.HAction.Run('TableCellBlockExtend'); [void]$Hwp.HAction.Run('TableLowerCell'); [void]$Hwp.HAction.Run('TableMergeCell'); [void]$Hwp.HAction.Run('Cancel')
    [void]$Hwp.HAction.Run('TableRightCell')
    [void]$Hwp.HAction.Run('TableCellBlock'); [void]$Hwp.HAction.Run('TableCellBlockExtend'); [void]$Hwp.HAction.Run('TableLowerCell')
    $out.extendedBlockDelete = [bool]$Hwp.HAction.Run('TableDeleteRow')
    [void]$Hwp.HAction.Run('Cancel')
    $out.extendedBlockRowCount = @((Read-HwpMarkup $Hwp).SelectNodes('//TABLE'))[-1].GetAttribute('RowCount')
    return $out
}
