[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Check','Install')][string]$Mode = 'Check',
    [string]$ModulePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$moduleName = 'FilePathCheckerModuleExample'
$subKey = 'Software\HNC\HwpAutomation\Modules'
$expectedHash = '9AC5B97C47AC8AED1E8BCA27A3EEF39411361D8F68C262509F0C40A8F9D21BB6'
if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($subKey,$false)
$hadValue = $false; $oldValue = $null; $oldKind = $null
try {
    if ($null -ne $key -and $key.GetValueNames() -contains $moduleName) {
        $hadValue = $true
        $oldValue = $key.GetValue($moduleName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $oldKind = $key.GetValueKind($moduleName)
    }
} finally { if ($null -ne $key) { $key.Dispose() } }
if ($Mode -eq 'Check') {
    $exists = $hadValue -and $oldKind -eq [Microsoft.Win32.RegistryValueKind]::String -and
        [IO.Path]::IsPathRooted([string]$oldValue) -and [IO.File]::Exists([string]$oldValue)
    $hash = if ($exists) { (Get-FileHash -LiteralPath ([string]$oldValue) -Algorithm SHA256).Hash } else { $null }
    [pscustomobject]@{Registered=$hadValue; Path=$oldValue; FileExists=$exists; Sha256=$hash; KnownHash=($hash -ceq $expectedHash); ComTested=$false}
    return
}
if (-not $ModulePath) { throw 'Install requires ModulePath to a DLL downloaded by the user from Hancom.' }
$source = (Resolve-Path -LiteralPath $ModulePath).Path
if (-not [IO.File]::Exists($source) -or [IO.Path]::GetExtension($source) -ine '.dll') { throw 'ModulePath must be a DLL file.' }
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $expectedHash) { throw 'Unexpected DLL hash; verify the official distribution before updating the known pin.' }
if (-not [Environment]::Is64BitProcess -or -not [Environment]::UserInteractive -or
    [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0 -or
    [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Use interactive Windows x64 PowerShell with -STA.' }
. (Join-Path $PSScriptRoot 'hancom-session.ps1')
$installRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('Hancom\HwpAutomation\' + $expectedHash.Substring(0,16))
$destination = Join-Path $installRoot ($moduleName + '.dll')
if (-not $PSCmdlet.ShouldProcess($destination,"Install verified DLL; update HKCU\$subKey\$moduleName; test RegisterModule")) { return }
[IO.Directory]::CreateDirectory($installRoot) | Out-Null
if ([IO.File]::Exists($destination)) {
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -cne $expectedHash) { throw 'Existing destination DLL has unexpected contents; it was not overwritten.' }
} else { [IO.File]::Copy($source,$destination,$false) }
if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -cne $expectedHash) { throw 'Installed DLL hash mismatch.' }
$mutationStarted = $false
try {
    $mutationStarted = $true
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($subKey)
    try { $key.SetValue($moduleName,$destination,[Microsoft.Win32.RegistryValueKind]::String) }
    finally { $key.Dispose() }
    # A separate owned Hancom process tests the module; open user windows are left alone.
    $owner = $null; $exit = $null
    try {
        $owner = Start-OwnedHwp
        if (-not $owner.Hwp.RegisterModule('FilePathCheckDLL',$moduleName)) { throw 'Hancom rejected the security module.' }
    } finally {
        $exit = Stop-OwnedHwp $owner
    }
    if ($exit -eq 'terminated') { throw 'Owned Hancom did not exit normally; registration will be restored.' }
} catch {
    $primary = $_
    if ($mutationStarted) {
        try {
            $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($subKey)
            try {
                if ($hadValue) { $key.SetValue($moduleName,$oldValue,$oldKind) }
                else { $key.DeleteValue($moduleName,$false) }
            } finally { $key.Dispose() }
        } catch { throw "Setup failed: $($primary.Exception.Message). Registry rollback also failed: $($_.Exception.Message)" }
    }
    throw $primary
}
[pscustomobject]@{Action='Installed'; Path=$destination; Sha256=$expectedHash; RegisterModule=$true; PreviousPath=$oldValue}
