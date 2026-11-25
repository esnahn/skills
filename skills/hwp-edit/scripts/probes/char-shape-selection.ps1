# CharShape applied to a selected range, SelectText positions around controls, and the shape new text
# takes after deleting part of a paragraph.
# Ledger: references/verified-api.md (CharShape on a selection; Selecting and deleting ranges).
function Invoke-HwpProbe {
    param($Hwp)
    $languages = 'Hangul','Latin','Hanja','Japanese','Other','Symbol','User'
    function Add-ProbeText([string]$Text) {
        $insert = $Hwp.HParameterSet.HInsertText
        $Hwp.HAction.GetDefault('InsertText', $insert.HSet) | Out-Null
        $insert.Text = $Text
        $Hwp.HAction.Execute('InsertText', $insert.HSet) | Out-Null
    }
    function Set-ProbeShape([hashtable]$Items) {
        $set = $Hwp.HParameterSet.HCharShape
        $Hwp.HAction.GetDefault('CharShape', $set.HSet) | Out-Null
        foreach ($key in $Items.Keys) { $set.HSet.SetItem($key, $Items[$key]) }
        return [bool]$Hwp.HAction.Execute('CharShape', $set.HSet)
    }
    function Select-ProbeRange([int]$Para, [int]$Start, [int]$End) {
        $Hwp.HAction.Run('Cancel') | Out-Null
        $Hwp.SelectText($Para, $Start, $Para, $End) | Out-Null
        return [string]$Hwp.GetTextFile('TEXT', 'saveblock')
    }
    function Get-ProbeRuns([int]$Index) {
        $xml = Read-HwpMarkup $Hwp
        $para = @($xml.SelectNodes('//BODY/SECTION/P'))[$Index]
        @($para.SelectNodes('./TEXT') | ForEach-Object {
            $shape = $xml.SelectSingleNode("//CHARSHAPELIST/CHARSHAPE[@Id='$($_.GetAttribute('CharShape'))']")
            $flags = @(if ($shape.SelectSingleNode('./BOLD')) { 'bold' }; if ($shape.SelectSingleNode('./SUPERSCRIPT')) { 'sup' }) -join '+'
            $text = -join @($_.SelectNodes('./CHAR') | ForEach-Object { $_.InnerText })
            "$text[$flags spacing=$($shape.SelectSingleNode('./CHARSPACING').GetAttribute('Hangul'))]"
        }) -join ' '
    }

    # Paragraph 0 of a blank document starts with the section and column definition controls.
    Add-ProbeText 'ABCDEFGHIJ'
    $blockAt2 = Select-ProbeRange 0 2 5
    $blockAt18 = Select-ProbeRange 0 18 21
    $boldReturned = Set-ProbeShape @{ Bold = 1 }
    $afterBold = Get-ProbeRuns 0
    $null = Select-ProbeRange 0 22 23
    $supReturned = Set-ProbeShape @{ SuperScript = 1 }
    $afterSup = Get-ProbeRuns 0
    # A selection spanning normal, bold and superscript text: set only letter spacing.
    $null = Select-ProbeRange 0 17 25
    $spacing = @{}; foreach ($language in $languages) { $spacing["Spacing$language"] = -5 }
    $spacingReturned = Set-ProbeShape $spacing
    $afterSpacing = Get-ProbeRuns 0

    # Paragraph 1 (no controls): "xy" normal, "BOLD" bold, "tail" normal; delete part of it, then type.
    $Hwp.HAction.Run('Cancel') | Out-Null
    $Hwp.HAction.Run('MoveDocEnd') | Out-Null
    $Hwp.HAction.Run('BreakPara') | Out-Null
    $reset = @{ Bold = 0; SuperScript = 0 }; foreach ($language in $languages) { $reset["Spacing$language"] = 0 }
    Set-ProbeShape $reset | Out-Null
    Add-ProbeText 'xy'
    Set-ProbeShape @{ Bold = 1 } | Out-Null
    Add-ProbeText 'BOLD'
    Set-ProbeShape @{ Bold = 0 } | Out-Null
    Add-ProbeText 'tail'
    $beforeDelete = Get-ProbeRuns 1
    $blockIn1 = Select-ProbeRange 1 3 10
    $Hwp.HAction.Run('Delete') | Out-Null
    Add-ProbeText 'new'
    $afterTypingAfterBold = Get-ProbeRuns 1
    $null = Select-ProbeRange 1 2 6
    $Hwp.HAction.Run('Delete') | Out-Null
    Add-ProbeText 'more'
    $afterTypingAfterNormal = Get-ProbeRuns 1

    # Paragraph 2: inline elements (fixed-width space, line break) each take one position.
    $Hwp.HAction.Run('Cancel') | Out-Null
    $Hwp.HAction.Run('MoveDocEnd') | Out-Null
    $Hwp.HAction.Run('BreakPara') | Out-Null
    Add-ProbeText 'a'
    $Hwp.HAction.Run('InsertFixedWidthSpace') | Out-Null
    Add-ProbeText 'bc'
    $Hwp.HAction.Run('BreakLine') | Out-Null
    Add-ProbeText 'de'
    $blockAfterSpace = Select-ProbeRange 2 2 4
    $blockAfterBreak = Select-ProbeRange 2 5 7

    # Paragraph 3: curly quotes and corner brackets survive the TEXT export of a block.
    $Hwp.HAction.Run('Cancel') | Out-Null
    $Hwp.HAction.Run('MoveDocEnd') | Out-Null
    $Hwp.HAction.Run('BreakPara') | Out-Null
    $marks = -join [char[]](0x201C, 0x78, 0x201D, 0x2018, 0x79, 0x2019, 0x300C, 0x7A, 0x300D)
    Add-ProbeText $marks
    $marksSurvive = ((Select-ProbeRange 3 0 9).TrimEnd("`r", "`n") -ceq $marks)
    $Hwp.HAction.Run('Cancel') | Out-Null

    return [ordered]@{
        paragraph0BlockAt2to5 = $blockAt2
        paragraph0BlockAt18to21 = $blockAt18
        boldReturned = $boldReturned
        afterBoldOnCDE = $afterBold
        superScriptReturned = $supReturned
        afterSuperScriptOnG = $afterSup
        spacingReturned = $spacingReturned
        afterSpacingOnBtoI = $afterSpacing
        paragraph1BlockAt3to10 = $blockIn1
        paragraph1BeforeDelete = $beforeDelete
        afterDeletingOLDtailAndTyping = $afterTypingAfterBold
        afterDeletingBnewAndTyping = $afterTypingAfterNormal
        paragraph2BlockAt2to4 = $blockAfterSpace
        paragraph2BlockAt5to7 = $blockAfterBreak
        curlyQuotesAndCornerBracketsSurviveSaveblock = $marksSurvive
    }
}
