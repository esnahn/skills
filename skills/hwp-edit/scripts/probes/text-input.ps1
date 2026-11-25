# InsertText, BreakLine, BreakPara, BreakPage: what each produces in the document structure.
# Ledger: references/verified-api.md (Text input and breaks).
function Invoke-HwpProbe {
    param($Hwp)
    function Add-ProbeText([string]$Text) {
        $set = $Hwp.HParameterSet.HInsertText
        $Hwp.HAction.GetDefault('InsertText', $set.HSet) | Out-Null
        $set.Text = $Text
        $Hwp.HAction.Execute('InsertText', $set.HSet) | Out-Null
    }
    Add-ProbeText 'first'
    $line = $Hwp.HAction.Run('BreakLine')
    Add-ProbeText 'second'
    $para = $Hwp.HAction.Run('BreakPara')
    Add-ProbeText 'third'
    $fixed = $Hwp.HAction.Run('InsertFixedWidthSpace')
    $nonBreaking = $Hwp.HAction.Run('InsertNonBreakingSpace')
    $page = $Hwp.HAction.Run('BreakPage')
    Add-ProbeText 'fourth'

    $paragraphs = @((Read-HwpMarkup $Hwp).SelectNodes('//BODY/SECTION/P'))
    return [ordered]@{
        runReturned = [ordered]@{ BreakLine = [bool]$line; BreakPara = [bool]$para; InsertFixedWidthSpace = [bool]$fixed; InsertNonBreakingSpace = [bool]$nonBreaking; BreakPage = [bool]$page }
        paragraphs = @($paragraphs | ForEach-Object {
            [ordered]@{
                text = (-join @($_.SelectNodes('./TEXT/CHAR') | ForEach-Object { foreach ($n in $_.ChildNodes) { if ($n.NodeType -eq 'Element') { "<$($n.Name)>" } else { $n.Value } } }))
                lineBreaks = $_.SelectNodes('.//LINEBREAK').Count
                pageBreakAttribute = $_.GetAttribute('PageBreak')
            }
        })
        pageCount = [int]$Hwp.PageCount
        plainText = [string]$Hwp.GetTextFile('TEXT','')
    }
}
