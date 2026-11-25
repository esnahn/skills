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
    $page = $Hwp.HAction.Run('BreakPage')
    Add-ProbeText 'fourth'

    $paragraphs = @((Read-HwpMarkup $Hwp).SelectNodes('//BODY/SECTION/P'))
    return [ordered]@{
        runReturned = [ordered]@{ BreakLine = [bool]$line; BreakPara = [bool]$para; BreakPage = [bool]$page }
        paragraphs = @($paragraphs | ForEach-Object {
            [ordered]@{
                text = (-join @($_.SelectNodes('./TEXT/CHAR') | ForEach-Object { $_.InnerText }))
                lineBreaks = $_.SelectNodes('.//LINEBREAK').Count
                pageBreakAttribute = $_.GetAttribute('PageBreak')
            }
        })
        pageCount = [int]$Hwp.PageCount
        plainText = [string]$Hwp.GetTextFile('TEXT','')
    }
}
