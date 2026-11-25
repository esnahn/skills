[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProbeScript,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$InputPath
)
# Runs one probe in an owned Hancom process, on a blank document or on a private copy of InputPath.
# Nothing is saved or published; the JSON record at OutputPath is the only output.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hancom-session.ps1')

$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { throw 'Output already exists; choose a new path.' }
if (-not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($output))) { throw 'Output parent directory must exist.' }
$probePath = (Resolve-Path -LiteralPath $ProbeScript).Path
$source = $null; $format = $null; $sourceHash = $null
if ($InputPath) {
    $source = (Resolve-Path -LiteralPath $InputPath).Path
    $format = Get-HwpDocumentFormat $source
    $sourceHash = Get-SharedFileHash $source
}
Assert-HwpAutomationHost
. $probePath
if (-not (Get-Command Invoke-HwpProbe -CommandType Function -ErrorAction SilentlyContinue)) { throw 'ProbeScript must define Invoke-HwpProbe.' }

$record = [ordered]@{
    probe = $probePath; date = (Get-Date).ToString('yyyy-MM-dd'); hancomBuild = $null; hancomExecutable = $null
    input = $source; inputSha256 = $sourceHash; ok = $false; result = $null; error = $null
}
$owner = $null; $temporary = $null
try {
    try {
        if ($source) {
            $temporary = Join-Path ([IO.Path]::GetDirectoryName($output)) ('.hwp-probe-' + [Guid]::NewGuid().ToString('N') + [IO.Path]::GetExtension($source))
            Copy-SharedFile $source $temporary
        }
        $owner = Start-OwnedHwp
        $record.hancomBuild = $owner.Build; $record.hancomExecutable = $owner.Executable
        Initialize-OwnedHwp $owner
        if ($temporary) { Open-HwpDocument $owner.Hwp $temporary $format }
        $result = @(Invoke-HwpProbe -Hwp $owner.Hwp)
        if ($result.Count -ne 1 -or $result[0] -isnot [Collections.IDictionary]) {
            throw 'Invoke-HwpProbe must return exactly one dictionary of observations; pipe incidental COM output to Out-Null.'
        }
        $record.result = $result[0]; $record.ok = $true
    } catch { $record.error = [string]$_.Exception.Message }
} finally {
    try {
        if ((Stop-OwnedHwp $owner -ClearDocument) -eq 'terminated') {
            $record.ok = $false; $record.error = (@($record.error, 'Owned Hancom did not exit normally and was stopped.') | Where-Object { $_ }) -join ' '
        }
        if ($source -and (Get-SharedFileHash $source) -cne $sourceHash) { $record.ok = $false; $record.error = 'Input changed during the probe.' }
    } finally {
        if ($temporary -and [IO.File]::Exists($temporary)) { Remove-Item -LiteralPath $temporary }
        Write-JsonFile $record $output
    }
}
if (-not $record.ok) { [Console]::Error.WriteLine("Probe failed (Hancom $($record.hancomBuild)): $($record.error) -> $output"); exit 1 }
Write-Output "Probe ok (Hancom $($record.hancomBuild)): $output"
