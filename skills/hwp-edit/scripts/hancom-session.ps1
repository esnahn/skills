# Shared Hancom COM helpers (dot-source this file).
# Each run starts its own HWP process and only ever closes that process.
# Hancom windows the user already has open are recorded and never touched.
Set-StrictMode -Version Latest

if (-not ('HwpEdit.NativeWindow' -as [type])) {
    Add-Type -Namespace HwpEdit -Name NativeWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint processId);
'@
}

function Assert-HwpAutomationHost {
    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess -or
        -not [Environment]::UserInteractive -or [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0 -or
        [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Use interactive Windows x64 PowerShell with -STA.' }
    $moduleKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\HNC\HwpAutomation\Modules',$false)
    try {
        if ($null -eq $moduleKey) { throw 'Hancom security module is not registered; user setup is required.' }
        $modulePath = [string]$moduleKey.GetValue('FilePathCheckerModuleExample')
        if (-not [IO.Path]::IsPathRooted($modulePath) -or -not [IO.File]::Exists($modulePath)) { throw 'Registered security DLL is missing.' }
    } finally { if ($null -ne $moduleKey) { $moduleKey.Dispose() } }
}

function Get-HwpDocumentFormat([string]$Path) {
    # Hancom format name per extension; open, save and reopen all use the document's own format.
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.hwp' { return 'HWP' }
        '.hwpx' { return 'HWPX' }
        default { throw 'Document must be an existing .hwp or .hwpx file.' }
    }
}

function Open-SharedRead([string]$Path) {
    # Hancom keeps open documents locked; read-share lets us still read the saved file.
    return [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]'ReadWrite, Delete')
}

function Get-SharedFileHash([string]$Path) {
    $stream = Open-SharedRead $Path
    try { return (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash } finally { $stream.Dispose() }
}

function Copy-SharedFile([string]$Source, [string]$Destination) {
    $reader = Open-SharedRead $Source
    try {
        $writer = [IO.File]::Open($Destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $reader.CopyTo($writer) } finally { $writer.Dispose() }
    } finally { $reader.Dispose() }
}

function Write-JsonFile($Value, [string]$Path) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 40), [Text.UTF8Encoding]::new($false))
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
        # The build that verified facts are tagged with (references/verified-api.md).
        $executable = [string]$process.Path
        $build = if ($executable) { [string](Get-Item -LiteralPath $executable).VersionInfo.FileVersion } else { '' }
        return [pscustomobject]@{
            Hwp = $hwp
            ProcessId = [int]$processId
            StartTime = $process.StartTime.ToFileTimeUtc()
            Preexisting = @($before.Keys)
            Executable = $executable
            Build = $(if ($build) { $build } else { 'unknown' })
        }
    } catch {
        # Release our reference only; never Clear/Quit a process we do not own.
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject($hwp) | Out-Null
        throw
    }
}

function Initialize-OwnedHwp($Owner) {
    # The security module must be accepted before any document is opened.
    if (-not $Owner.Hwp.RegisterModule('FilePathCheckDLL','FilePathCheckerModuleExample')) { throw 'RegisterModule failed.' }
    $Owner.Hwp.XHwpWindows.Item(0).Visible = $false
}

function Open-HwpDocument($Hwp, [string]$Path, [string]$Format) {
    if (-not $Hwp.Open($Path,$Format,'lock:false;forceopen:true;suspendpassword:true;versionwarning:false')) { throw "$Format open failed: $Path" }
}

function Read-HwpMarkup($Hwp) {
    # The open document as HWPML; task scripts and probes read shapes and structure back from it.
    $xml = New-Object Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.XmlResolver = $null
    $xml.LoadXml([string]$Hwp.GetTextFile('HWPML2X',''))
    return ,$xml
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
