# CreatePageImage on a freshly opened long document: later pages fail until the caret visits the end.
# The probe writes its own long document to a temporary file, reopens it, and deletes it afterwards.
# Ledger: references/verified-api.md (CreatePageImage).
function Invoke-HwpProbe {
    param($Hwp)
    $insert = $Hwp.HParameterSet.HInsertText
    for ($i = 0; $i -lt 400; $i++) {
        $Hwp.HAction.GetDefault('InsertText', $insert.HSet) | Out-Null
        $insert.Text = "Line $i of a long sample document used to exercise lazy page layout after reopening."
        $Hwp.HAction.Execute('InsertText', $insert.HSet) | Out-Null
        [void]$Hwp.HAction.Run('BreakPara')
    }
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('hwp-probe-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $dir | Out-Null
    $file = Join-Path $dir 'long.hwpx'
    $out = [ordered]@{}
    try {
        if (-not $Hwp.SaveAs($file, 'HWPX', '')) { throw 'SaveAs failed.' }
        $Hwp.Clear(1) | Out-Null
        if (-not $Hwp.Open($file, 'HWPX', 'lock:false;forceopen:true;suspendpassword:true;versionwarning:false')) { throw 'Open failed.' }
        $out.pageCount = [int]$Hwp.PageCount
        $last = [int]$Hwp.PageCount - 1
        $out.firstPageBeforeMove = [bool]$Hwp.CreatePageImage((Join-Path $dir 'a.bmp'), 0, 72, 24, 'bmp')
        $out.lastPageBeforeMove = [bool]$Hwp.CreatePageImage((Join-Path $dir 'b.bmp'), $last, 72, 24, 'bmp')
        [void]$Hwp.HAction.Run('MoveDocEnd')
        $out.lastPageAfterMoveDocEnd = [bool]$Hwp.CreatePageImage((Join-Path $dir 'c.bmp'), $last, 72, 24, 'bmp')
    } finally {
        $Hwp.Clear(1) | Out-Null
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
    return $out
}
