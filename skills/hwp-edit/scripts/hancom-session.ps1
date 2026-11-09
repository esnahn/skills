# Owned Hancom COM session helpers (dot-source this file).
# Each run starts its own HWP process and only ever closes that process.
# Hancom windows the user already has open are recorded and never touched.
Set-StrictMode -Version Latest

if (-not ('HwpEdit.NativeWindow' -as [type])) {
    Add-Type -Namespace HwpEdit -Name NativeWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint processId);
'@
}

function Get-HwpProcessTable {
    $table = @{}
    foreach ($process in @(Get-Process -Name Hwp,Hwp64 -ErrorAction SilentlyContinue)) {
        $table[[int]$process.Id] = $process.StartTime.ToFileTimeUtc()
    }
    return $table
}

function Test-OwnedHwpAlive($Owner) {
    # PID plus start time, so a reused PID is never mistaken for ours.
    $process = Get-Process -Id $Owner.ProcessId -ErrorAction SilentlyContinue
    return ($null -ne $process -and $process.ProcessName -in @('Hwp','Hwp64') -and
        $process.StartTime.ToFileTimeUtc() -eq $Owner.StartTime)
}

function Start-OwnedHwp {
    $before = Get-HwpProcessTable
    $hwp = New-Object -ComObject HWPFrame.HwpObject
    try {
        $handle = [IntPtr][long]$hwp.XHwpWindows.Active_XHwpWindow.WindowHandle
        [uint32]$processId = 0
        [void][HwpEdit.NativeWindow]::GetWindowThreadProcessId($handle, [ref]$processId)
        if ($processId -eq 0) { throw 'Could not identify the Hancom process behind the COM object.' }
        if ($before.ContainsKey([int]$processId)) {
            throw "COM returned a preexisting Hancom process ($processId); it was left untouched."
        }
        $process = Get-Process -Id $processId
        if ($process.ProcessName -notin @('Hwp','Hwp64')) { throw "Unexpected COM server process: $($process.ProcessName)" }
        return [pscustomobject]@{
            Hwp = $hwp
            ProcessId = [int]$processId
            StartTime = $process.StartTime.ToFileTimeUtc()
            Preexisting = @($before.Keys)
        }
    } catch {
        # Release our reference only; never Clear/Quit a process we do not own.
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject($hwp) | Out-Null
        throw
    }
}

function Stop-OwnedHwp($Owner, [switch]$ClearDocument) {
    # Returns 'exited' after a normal Quit, 'terminated' when the owned process had to be stopped.
    if ($null -eq $Owner) { return 'none' }
    $hwp = $Owner.Hwp
    try {
        if ($ClearDocument) { try { $hwp.Clear(1) | Out-Null } catch { } }
        try { $hwp.Quit() | Out-Null } catch { }
    } finally {
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject($hwp) | Out-Null
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while ((Test-OwnedHwpAlive $Owner) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
    if (-not (Test-OwnedHwpAlive $Owner)) { return 'exited' }
    Stop-Process -Id $Owner.ProcessId -Force
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((Test-OwnedHwpAlive $Owner) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (Test-OwnedHwpAlive $Owner) { throw "Owned Hancom process $($Owner.ProcessId) could not be stopped." }
    return 'terminated'
}
