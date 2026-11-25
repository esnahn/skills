# PutFieldText / MoveToField on a named cell holding two paragraphs; clearing a cell; deleting
# paragraph ranges with SelectText and MoveSelDocEnd. Ledger: references/verified-api.md
# (PutFieldText and MoveToField; Selecting and deleting ranges).
function Invoke-HwpProbe {
    param($Hwp)
    function Add-ProbeText([string]$Text) { $s = $Hwp.HParameterSet.HInsertText; $Hwp.HAction.GetDefault('InsertText', $s.HSet) | Out-Null; $s.Text = $Text; $Hwp.HAction.Execute('InsertText', $s.HSet) | Out-Null }
    function Set-Align([int]$Align) { $p = $Hwp.HParameterSet.HParaShape; $Hwp.HAction.GetDefault('ParagraphShape', $p.HSet) | Out-Null; $p.AlignType = $Align; $Hwp.HAction.Execute('ParagraphShape', $p.HSet) | Out-Null }
    function Get-Top { @((Read-HwpMarkup $Hwp).SelectNodes('//BODY/SECTION/P') | ForEach-Object { (-join @($_.SelectNodes('./TEXT/CHAR') | ForEach-Object { $_.InnerText })) + $(if ($_.SelectSingleNode('./TEXT/TABLE')) { '[TABLE]' }) }) }
    $out = [ordered]@{}
    foreach ($t in 'p1','p2','p3') { Add-ProbeText $t; [void]$Hwp.HAction.Run('BreakPara') }
    $create = $Hwp.HParameterSet.HTableCreation
    $Hwp.HAction.GetDefault('TableCreate', $create.HSet) | Out-Null
    $create.Rows = 1; $create.Cols = 2; $create.TableProperties.TreatAsChar = 1
    $Hwp.HAction.Execute('TableCreate', $create.HSet) | Out-Null
    # Named first cell with a left-aligned then a right-aligned paragraph.
    [void]$Hwp.SetCurFieldName('named', 1, '', '')
    Set-Align 1; Add-ProbeText 'left'; [void]$Hwp.HAction.Run('BreakPara'); Set-Align 2; Add-ProbeText 'right'
    [void]$Hwp.HAction.Run('TableRightCell'); Add-ProbeText 'unnamed'
    $Hwp.PutFieldText('named{{0}}', 'filled')
    $xml = Read-HwpMarkup $Hwp
    $cell = $xml.SelectSingleNode("//CELL[@Name='named']")
    $out.afterPutFieldText = @($cell.SelectNodes('./PARALIST/P') | ForEach-Object { (-join @($_.SelectNodes('./TEXT/CHAR') | ForEach-Object { $_.InnerText })) + ' align=' + $xml.SelectSingleNode("//PARASHAPE[@Id='$($_.GetAttribute('ParaShape'))']").GetAttribute('Align') })
    # Clear the unnamed cell: reach it from the named one, select the list, delete, type.
    $out.moveToField = [bool]$Hwp.MoveToField('named{{0}}', $true, $true, $false)
    [void]$Hwp.HAction.Run('TableRightCell')
    $out.clearReturns = @([bool]$Hwp.HAction.Run('MoveListBegin'), [bool]$Hwp.HAction.Run('MoveSelListEnd'), [bool]$Hwp.HAction.Run('Delete'))
    Add-ProbeText 'replaced'
    $out.secondCell = -join @((Read-HwpMarkup $Hwp).SelectNodes("//CELL[@ColAddr='1']//CHAR") | ForEach-Object { $_.InnerText })
    $out.topBefore = Get-Top
    # Delete paragraphs 1-2 (p2, p3) with SelectText in the root list.
    [void]$Hwp.HAction.Run('MoveDocBegin')
    $out.selectText = [bool]$Hwp.SelectText(1, 0, 3, 0)
    [void]$Hwp.HAction.Run('Delete')
    $out.topAfterSelectText = Get-Top
    # From the end of paragraph 0, select to the document end and delete: no empty paragraph remains.
    [void]$Hwp.HAction.Run('MoveDocBegin'); [void]$Hwp.SelectText(1, 0, 1, 0)
    $out.moveLeftToPreviousEnd = [bool]$Hwp.HAction.Run('MoveLeft')
    [void]$Hwp.HAction.Run('MoveSelDocEnd'); [void]$Hwp.HAction.Run('Delete')
    $out.topAfterDocEndDelete = Get-Top
    return $out
}
