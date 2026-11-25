# PageNumPos and PageHiding: a "- n -" page number at bottom centre, hidden on the current page.
# Ledger: references/verified-api.md (PageNumPos, PageHiding).
function Invoke-HwpProbe {
    param($Hwp)
    $number = $Hwp.HParameterSet.HPageNumPos
    $Hwp.HAction.GetDefault('PageNumPos', $number.HSet) | Out-Null
    $number.DrawPos = 5          # bottom centre
    $number.NumberFormat = 0     # 1, 2, 3
    $number.SideChar = [int][char]'-'
    $numberReturned = $Hwp.HAction.Execute('PageNumPos', $number.HSet)

    $hiding = $Hwp.HParameterSet.HPageHiding
    $Hwp.HAction.GetDefault('PageHiding', $hiding.HSet) | Out-Null
    $hiding.Fields = 0x20        # page number
    $hidingReturned = $Hwp.HAction.Execute('PageHiding', $hiding.HSet)

    $xml = Read-HwpMarkup $Hwp
    return [ordered]@{
        executeReturned = [ordered]@{ PageNumPos = [bool]$numberReturned; PageHiding = [bool]$hidingReturned }
        pageNum = @($xml.SelectNodes('//PAGENUM') | ForEach-Object { $_.OuterXml })
        pageHiding = @($xml.SelectNodes('//PAGEHIDING') | ForEach-Object { $_.OuterXml })
    }
}
