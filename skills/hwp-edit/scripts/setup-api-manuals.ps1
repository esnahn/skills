[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Check','Install')][string]$Mode = 'Check',
    [string]$From,
    [switch]$Download,
    [string]$ManualRoot = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Hancom\HwpAutomation\manuals')
)
# Official Hancom automation manuals (references/api-sources.md), kept per user outside the skill.
# Check only reads. Install copies verified files from -From and/or downloads them from the official archive.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$baseUrl = 'https://github.com/hancom-io/devcenter-archive/raw/main/hwp-automation/'
# Git blob SHA-1 of each file, as listed by the archive (git hash-object --no-filters).
$manuals = [ordered]@{
    'ActionTable_2504.pdf' = '162e5e70f812515d9a90e3fd888f328e6f80e26f'
    'ParameterSetTable_2504.pdf' = '50ff092e81c81f8bba54a17d98b6aa4d909e6f87'
    'HwpAutomation_2504.pdf' = '9985830b299ee1958ed41ab89e57fb8fc531bca7'
    '한글오토메이션EventHandler추가_2504.pdf' = 'a46b8a88c844ff2a638b42645ea8fc8334c2e42d'
}

function Get-GitBlobSha([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $header = [Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $sha = [Security.Cryptography.SHA1]::Create()
    try {
        [void]$sha.TransformBlock($header,0,$header.Length,$null,0)
        [void]$sha.TransformFinalBlock($bytes,0,$bytes.Length)
        return -join ($sha.Hash | ForEach-Object { $_.ToString('x2') })
    } finally { $sha.Dispose() }
}
function Get-ManualState {
    foreach ($name in $manuals.Keys) {
        $path = Join-Path $ManualRoot $name
        $present = [IO.File]::Exists($path)
        $sha = if ($present) { Get-GitBlobSha $path } else { $null }
        [pscustomobject]@{Name=$name; Present=$present; Verified=($sha -ceq $manuals[$name]); Path=$path}
    }
}

if ($Mode -eq 'Check') { Get-ManualState; return }
if (-not $From -and -not $Download) { throw 'Install needs -From <folder with copies> and/or -Download (official archive; ask the user first).' }
$fromRoot = if ($From) { (Resolve-Path -LiteralPath $From).Path } else { $null }
$missing = @(Get-ManualState | Where-Object { -not $_.Verified })
foreach ($item in $missing) {
    if ($item.Present) { throw "$($item.Path) exists with unexpected contents; it was not overwritten. Check for a newer official release before changing the pinned SHA." }
}
if ($missing.Count -eq 0) { Get-ManualState; return }
if (-not $PSCmdlet.ShouldProcess($ManualRoot, "Install $($missing.Count) verified manual(s)")) { return }
[IO.Directory]::CreateDirectory($ManualRoot) | Out-Null
$staging = [IO.Directory]::CreateDirectory((Join-Path $ManualRoot ('.staging-' + [Guid]::NewGuid().ToString('N')))).FullName
try {
    foreach ($item in $missing) {
        $expected = $manuals[$item.Name]
        $staged = Join-Path $staging $item.Name
        $candidate = if ($fromRoot) {
            Get-ChildItem -LiteralPath $fromRoot -Recurse -File -Filter $item.Name -ErrorAction SilentlyContinue |
                Where-Object { (Get-GitBlobSha $_.FullName) -ceq $expected } | Select-Object -First 1
        } else { $null }
        if ($candidate) { [IO.File]::Copy($candidate.FullName, $staged, $false) }
        elseif ($Download) { Invoke-WebRequest -Uri ($baseUrl + [Uri]::EscapeDataString($item.Name)) -OutFile $staged -UseBasicParsing }
        else { throw "No verified copy of $($item.Name) under $fromRoot." }
        if ((Get-GitBlobSha $staged) -cne $expected) { throw "$($item.Name) does not match the pinned SHA; nothing from it was installed." }
        [IO.File]::Move($staged, $item.Path)
    }
} finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}
Get-ManualState
