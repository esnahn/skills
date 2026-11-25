# PageSetup (SecDef/PageDef): paper size and margins for the whole document.
# Ledger: references/verified-api.md (PageSetup).
function Invoke-HwpProbe {
    param($Hwp)
    $before = (Read-HwpMarkup $Hwp).SelectSingleNode('//PAGEDEF')
    $set = $Hwp.HParameterSet.HSecDef
    $Hwp.HAction.GetDefault('PageSetup', $set.HSet) | Out-Null
    # A4 portrait, 20 mm left/right, 15 mm top/bottom, 10 mm header/footer (1 mm = 283.465 HWPUNIT).
    $set.PageDef.PaperWidth = 59528
    $set.PageDef.PaperHeight = 84186
    $set.PageDef.LeftMargin = 5669
    $set.PageDef.RightMargin = 5669
    $set.PageDef.TopMargin = 4252
    $set.PageDef.BottomMargin = 4252
    $set.PageDef.HeaderLen = 2835
    $set.PageDef.FooterLen = 2835
    $set.PageDef.GutterLen = 0
    $set.HSet.SetItem('ApplyClass', 24)
    $set.HSet.SetItem('ApplyTo', 3)
    $returned = $Hwp.HAction.Execute('PageSetup', $set.HSet)
    $after = (Read-HwpMarkup $Hwp).SelectSingleNode('//PAGEDEF')
    $margin = $after.SelectSingleNode('./PAGEMARGIN')
    return [ordered]@{
        executeReturned = [bool]$returned
        before = [ordered]@{ width = $before.GetAttribute('Width'); height = $before.GetAttribute('Height'); margins = $before.SelectSingleNode('./PAGEMARGIN').OuterXml }
        width = $after.GetAttribute('Width'); height = $after.GetAttribute('Height')
        left = $margin.GetAttribute('Left'); right = $margin.GetAttribute('Right')
        top = $margin.GetAttribute('Top'); bottom = $margin.GetAttribute('Bottom')
        header = $margin.GetAttribute('Header'); footer = $margin.GetAttribute('Footer'); gutter = $margin.GetAttribute('Gutter')
    }
}
