# ParagraphShape at the caret: alignment, margins, spacing; and how the "URC" margin unit maps to HWPML.
# Ledger: references/verified-api.md (ParagraphShape).
function Invoke-HwpProbe {
    param($Hwp)
    $set = $Hwp.HParameterSet.HParaShape
    $Hwp.HAction.GetDefault('ParagraphShape', $set.HSet) | Out-Null
    $set.AlignType = 4           # distribute
    $set.LeftMargin = 2000
    $set.RightMargin = 3000
    $set.Indentation = 0
    $set.PrevSpacing = 400
    $set.NextSpacing = 1600
    $set.LineSpacingType = 0     # percent
    $set.LineSpacing = 165
    $set.Condense = 50
    $set.WidowOrphan = 1
    $set.BreakNonLatinWord = 1
    $returned = $Hwp.HAction.Execute('ParagraphShape', $set.HSet)

    $insert = $Hwp.HParameterSet.HInsertText
    $Hwp.HAction.GetDefault('InsertText', $insert.HSet) | Out-Null
    $insert.Text = 'sample paragraph'
    $Hwp.HAction.Execute('InsertText', $insert.HSet) | Out-Null

    # LineWrap (ParameterSetTable mislabels it as a line-height flag): value -> HWPML name, one paragraph each.
    foreach ($value in 0, 1, 2) {
        $Hwp.HAction.Run('BreakPara') | Out-Null
        $wrap = $Hwp.HParameterSet.HParaShape
        $Hwp.HAction.GetDefault('ParagraphShape', $wrap.HSet) | Out-Null
        $wrap.LineWrap = $value
        $Hwp.HAction.Execute('ParagraphShape', $wrap.HSet) | Out-Null
        $Hwp.HAction.GetDefault('InsertText', $insert.HSet) | Out-Null
        $insert.Text = "line wrap $value"
        $Hwp.HAction.Execute('InsertText', $insert.HSet) | Out-Null
    }

    $xml = Read-HwpMarkup $Hwp
    $lineWrap = [ordered]@{}
    foreach ($p in @($xml.SelectNodes('//BODY/SECTION/P'))[1..3]) {
        $lineWrap[(-join @($p.SelectNodes('./TEXT/CHAR') | ForEach-Object { $_.InnerText }))] = $xml.SelectSingleNode("//PARASHAPE[@Id='$($p.GetAttribute('ParaShape'))']").GetAttribute('LineWrap')
    }
    $paragraph = $xml.SelectSingleNode('//BODY/SECTION/P')
    $shape = $xml.SelectSingleNode("//PARASHAPELIST/PARASHAPE[@Id='$($paragraph.GetAttribute('ParaShape'))']")
    $margin = $shape.SelectSingleNode('./PARAMARGIN')
    return [ordered]@{
        executeReturned = [bool]$returned
        align = $shape.GetAttribute('Align')
        condense = $shape.GetAttribute('Condense')
        widowOrphan = $shape.GetAttribute('WidowOrphan')
        breakNonLatinWord = $shape.GetAttribute('BreakNonLatinWord')
        lineWrap = $lineWrap
        set = [ordered]@{ left = 2000; right = 3000; prev = 400; next = 1600 }
        markup = [ordered]@{
            left = $margin.GetAttribute('Left'); right = $margin.GetAttribute('Right')
            prev = $margin.GetAttribute('Prev'); next = $margin.GetAttribute('Next')
            lineSpacing = $margin.GetAttribute('LineSpacing'); lineSpacingType = $margin.GetAttribute('LineSpacingType')
        }
    }
}
