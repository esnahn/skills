# CharShape at the caret before typing: font faces, size, bold, width ratio, letter spacing.
# Ledger: references/verified-api.md (CharShape).
function Invoke-HwpProbe {
    param($Hwp)
    $face = '함초롬돋움'
    $languages = 'Hangul','Latin','Hanja','Japanese','Other','Symbol','User'
    $set = $Hwp.HParameterSet.HCharShape
    $Hwp.HAction.GetDefault('CharShape', $set.HSet) | Out-Null
    foreach ($language in $languages) {
        $set.HSet.SetItem("FaceName$language", $face)
        $set.HSet.SetItem("FontType$language", 1)
        $set.HSet.SetItem("Ratio$language", 90)
        $set.HSet.SetItem("Spacing$language", -10)
    }
    # Hancom's own HFT fonts need FontType 2; HCI Poppy ships with Hancom.
    $set.HSet.SetItem('FaceNameLatin', 'HCI Poppy')
    $set.HSet.SetItem('FontTypeLatin', 2)
    $set.HSet.SetItem('SizeHangul', 90)
    $set.HSet.SetItem('OffsetHangul', 10)
    $set.Italic = 1
    $set.UnderlineType = 1; $set.UnderlineShape = 0; $set.UnderlineColor = 0x000000FF
    $set.SuperScript = 1
    $set.Height = 2200
    $set.Bold = 1
    $set.TextColor = 0x00ECE3E3
    $returned = $Hwp.HAction.Execute('CharShape', $set.HSet)

    $insert = $Hwp.HParameterSet.HInsertText
    $Hwp.HAction.GetDefault('InsertText', $insert.HSet) | Out-Null
    $insert.Text = 'sample'
    $Hwp.HAction.Execute('InsertText', $insert.HSet) | Out-Null

    $xml = Read-HwpMarkup $Hwp
    $text = @($xml.SelectNodes('//BODY//TEXT') | Where-Object { $_.InnerText -ceq 'sample' })[0]
    $shape = $xml.SelectSingleNode("//CHARSHAPELIST/CHARSHAPE[@Id='$($text.GetAttribute('CharShape'))']")
    $fonts = [ordered]@{}
    foreach ($language in $languages) {
        $id = $shape.SelectSingleNode('./FONTID').GetAttribute($language)
        $font = $xml.SelectSingleNode("//FACENAMELIST/FONTFACE[@Lang='$language']/FONT[@Id='$id']")
        $fonts[$language] = "$($font.GetAttribute('Name'))/$($font.GetAttribute('Type'))"
    }
    return [ordered]@{
        executeReturned = [bool]$returned
        fonts = $fonts
        height = $shape.GetAttribute('Height')
        textColor = $shape.GetAttribute('TextColor')
        bold = ($null -ne $shape.SelectSingleNode('./BOLD'))
        ratioHangul = $shape.SelectSingleNode('./RATIO').GetAttribute('Hangul')
        spacingHangul = $shape.SelectSingleNode('./CHARSPACING').GetAttribute('Hangul')
        relSizeHangul = $shape.SelectSingleNode('./RELSIZE').GetAttribute('Hangul')
        offsetHangul = $shape.SelectSingleNode('./CHAROFFSET').GetAttribute('Hangul')
        flags = @($shape.ChildNodes | Where-Object { $_.Name -in 'ITALIC','UNDERLINE','SUPERSCRIPT','SUBSCRIPT','STRIKEOUT' } | ForEach-Object { $_.OuterXml })
    }
}
