# AllReplace (FindReplace parameter set): does whole-document replacement work, and does Execute's
# return value tell whether anything was replaced? Ledger: references/verified-api.md (AllReplace).
function Invoke-HwpProbe {
    param($Hwp)
    $insert = $Hwp.HParameterSet.HInsertText
    $Hwp.HAction.GetDefault('InsertText', $insert.HSet) | Out-Null
    $insert.Text = 'alpha beta alpha'
    $Hwp.HAction.Execute('InsertText', $insert.HSet) | Out-Null

    function Get-ProbeText { ([string]$Hwp.GetTextFile('TEXT','')).Trim() }
    function Invoke-ProbeReplace([string]$Find, [string]$Replace, [string]$Cursor) {
        if ($Cursor -eq 'start') { $Hwp.MovePos(2,0,0) | Out-Null } else { $Hwp.MovePos(3,0,0) | Out-Null }
        $set = $Hwp.HParameterSet.HFindReplace
        $Hwp.HAction.GetDefault('AllReplace', $set.HSet) | Out-Null
        $set.FindString = $Find; $set.ReplaceString = $Replace; $set.IgnoreMessage = 1; $set.Direction = 2
        $returned = $Hwp.HAction.Execute('AllReplace', $set.HSet)
        [ordered]@{ find = $Find; replace = $Replace; cursor = $Cursor; returned = [bool]$returned; textAfter = (Get-ProbeText) }
    }
    $cases = @(
        Invoke-ProbeReplace 'beta' 'delta' 'start'     # one hit, cursor at document start
        Invoke-ProbeReplace 'alpha' 'gamma' 'start'    # two hits, cursor at document start
        Invoke-ProbeReplace 'delta' 'beta' 'end'       # one hit, cursor at document end
        Invoke-ProbeReplace 'zzz' 'yyy' 'start'        # no hit
    )
    return [ordered]@{
        cases = $cases
        allReplacementsApplied = ((Get-ProbeText) -ceq 'gamma beta gamma')
        returnValuesDiffer = (@($cases | ForEach-Object { $_.returned } | Select-Object -Unique).Count -gt 1)
    }
}
