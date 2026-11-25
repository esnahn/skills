[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Inspect','Fill','Edit','Create','Render','ValidatePlan')][string]$Mode,
    [string]$InputPath,
    [string]$OutputPath,
    [string]$PlanPath,
    [string]$TaskScript,
    [ValidateRange(72,600)][int]$Dpi = 150,
    [int[]]$Pages,
    [switch]$AllowTableGeometryChange
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hancom-session.ps1')

function Read-Plan([string]$Path) {
    if (-not $Path) { throw 'PlanPath is required.' }
    $plan = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path) | ConvertFrom-Json
    if (-not $plan -or -not ($plan.PSObject.Properties.Name -contains 'sourceSha256') -or
        [string]$plan.sourceSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Plan requires sourceSha256 (64 hex characters).' }
    if (-not ($plan.PSObject.Properties.Name -contains 'fields') -or $plan.fields -isnot [Array] -or $plan.fields.Count -eq 0) {
        throw 'Plan requires a nonempty fields array.'
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($entry in $plan.fields) {
        foreach ($key in @('name','expected','text')) {
            if (-not ($entry.PSObject.Properties.Name -contains $key) -or $entry.$key -isnot [string]) { throw "Each field requires string $key." }
            if ($entry.$key.Contains([string][char]2)) { throw 'Field separator U+0002 is not allowed.' }
        }
        if ($entry.name -notmatch '^.+\{\{[0-9]+\}\}$' -or -not $seen.Add($entry.name)) { throw 'Use unique indexed field names, e.g. applicant{{0}}.' }
    }
    return $plan
}
function Normalize-Text([string]$Text) { return $Text.Replace("`r`n", "`n").Replace("`r", "`n") }
function Get-NodePath($Node) {
    $parts = New-Object 'System.Collections.Generic.List[string]'
    while ($Node -is [Xml.XmlElement]) {
        $index = 1; $previous = $Node.PreviousSibling
        while ($null -ne $previous) { if ($previous.Name -eq $Node.Name) { $index++ }; $previous = $previous.PreviousSibling }
        $parts.Insert(0, ('{0}[{1}]' -f $Node.Name,$index)); $Node = $Node.ParentNode
    }
    return '/' + ($parts -join '/')
}
function Get-Geometry($Xml) {
    $items = foreach ($node in $Xml.SelectNodes('//TABLE | //ROW | //CELL')) {
        $attributes = [ordered]@{}
        foreach ($attr in @($node.Attributes) | Sort-Object Name) {
            if ($attr.Name -in @('RowCount','ColCount','RowAddr','ColAddr','RowSpan','ColSpan','Width')) { $attributes[$attr.Name] = $attr.Value }
        }
        $cellSize = $node.SelectSingleNode('./CELLSIZE')
        if ($null -ne $cellSize -and $cellSize.HasAttribute('Width')) { $attributes['CellWidth'] = $cellSize.GetAttribute('Width') }
        [ordered]@{path=(Get-NodePath $node); tag=$node.Name; attributes=$attributes}
    }
    return ConvertTo-Json -InputObject @($items) -Depth 10 -Compress
}
function Get-FieldValue($Hwp, [string]$Name) {
    # GetFieldText terminates fields with U+0002 on some versions.
    $value = [string]$Hwp.GetFieldText($Name)
    return Normalize-Text ($value.TrimEnd([char]2))
}
function Assert-Fields($Hwp, $Plan, [bool]$After) {
    $available = ([string]$Hwp.GetFieldList(1,0)).Split([char]2)
    foreach ($entry in $Plan.fields) {
        if (-not ($available -ccontains $entry.name)) { throw "Missing indexed field: $($entry.name)" }
        $expected = if ($After) { $entry.text } else { $entry.expected }
        if ((Get-FieldValue $Hwp $entry.name) -cne (Normalize-Text $expected)) { throw "Field content mismatch: $($entry.name)" }
    }
}
function Assert-Task($Hwp) {
    $result = @(Test-HwpEdit -Hwp $Hwp)
    if ($result.Count -ne 1 -or $result[0] -isnot [bool] -or -not $result[0]) { throw 'Test-HwpEdit must return exactly one true Boolean after real assertions.' }
}
function Get-FieldSnapshot($Hwp) {
    $snapshot = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    foreach ($name in ([string]$Hwp.GetFieldList(1,0)).Split([char]2)) {
        if ($name) { $snapshot.Add($name,(Get-FieldValue $Hwp $name)) }
    }
    return ,$snapshot
}
function Assert-ProtectedFields($Hwp, $Before, $Plan) {
    $after = Get-FieldSnapshot $Hwp
    if ($Before.Count -ne $after.Count) { throw 'Field count changed.' }
    foreach ($name in $Before.Keys) {
        if (-not $after.ContainsKey($name)) { throw "Field disappeared: $name" }
        if (-not (@($Plan.fields | ForEach-Object { $_.name }) -ccontains $name) -and $Before[$name] -cne $after[$name]) {
            throw "Unrequested field changed: $name"
        }
    }
}

if ($AllowTableGeometryChange -and $Mode -ne 'Edit') { throw 'AllowTableGeometryChange is supported only in Edit mode.' }
$plan = $null
if ($Mode -in @('Fill','ValidatePlan')) { $plan = Read-Plan $PlanPath }
if ($Mode -eq 'ValidatePlan') { Write-Output 'Plan valid; Hancom was not started.'; return }
if (-not $OutputPath) { throw 'OutputPath is required.' }
$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { throw 'Output already exists; choose a new path.' }
if (-not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($output))) { throw 'Output parent directory must exist.' }
$source = $null; $sourceHash = $null
if ($Mode -eq 'Create') {
    # A new document starts from Hancom's blank document; the output extension picks the format.
    if ($InputPath) { throw 'Create builds a new document; omit InputPath.' }
    $format = Get-HwpDocumentFormat $output
    $extension = [IO.Path]::GetExtension($output).ToLowerInvariant()
} else {
    if (-not $InputPath) { throw 'InputPath is required.' }
    $source = (Resolve-Path -LiteralPath $InputPath).Path
    if (-not [IO.File]::Exists($source)) { throw 'Input must be an existing .hwp or .hwpx file.' }
    $format = Get-HwpDocumentFormat $source
    $extension = [IO.Path]::GetExtension($source).ToLowerInvariant()
    if ($Mode -in @('Fill','Edit') -and [IO.Path]::GetExtension($output) -ine $extension) { throw "Edited output must keep the input extension ($extension); format conversion is not supported." }
}
Assert-HwpAutomationHost
if ($source) { $sourceHash = Get-SharedFileHash $source }
# Task scripts are dot-sourced into this scope and variable names ignore case; freezing these makes a
# colliding name (e.g. $script:Source in a task script) fail loudly instead of redirecting the run.
foreach ($name in 'source','sourceHash','output','format','extension','plan') { Set-Variable -Name $name -Option ReadOnly }
if ($Mode -in @('Edit','Create')) {
    if (-not $TaskScript) { throw "$Mode requires TaskScript defining Invoke-HwpEdit and Test-HwpEdit." }
    . (Resolve-Path -LiteralPath $TaskScript).Path
    foreach ($command in @('Invoke-HwpEdit','Test-HwpEdit')) {
        if (-not (Get-Command $command -CommandType Function -ErrorAction SilentlyContinue)) { throw "TaskScript must define $command." }
    }
}
if ($Mode -eq 'Fill' -and $sourceHash -ine $plan.sourceSha256) { throw 'Plan source hash mismatch; inspect this document again.' }
$owner = $null; $hwp = $null; $temporary = $null; $success = $false; $build = 'unknown'
try {
    # Hancom always works on a private snapshot, so a source open in the user's Hancom is fine.
    $workDirectory = if ($Mode -in @('Fill','Edit','Create')) { [IO.Path]::GetDirectoryName($output) } else { [IO.Directory]::CreateDirectory($output).FullName }
    $temporary = Join-Path $workDirectory ('.hwp-edit-' + [Guid]::NewGuid().ToString('N') + $extension)
    if ($source) {
        Copy-SharedFile $source $temporary
        if ((Get-SharedFileHash $temporary) -cne $sourceHash) { throw 'Source changed while it was being copied; try again.' }
    }
    $owner = Start-OwnedHwp; $hwp = $owner.Hwp
    Initialize-OwnedHwp $owner
    if ($source) { Open-HwpDocument $hwp $temporary $format }
    if ($Mode -eq 'Create') {
        Invoke-HwpEdit -Hwp $hwp | Out-Null; Assert-Task $hwp
        if (-not $hwp.SaveAs($temporary,$format,'')) { throw 'Save failed.' }
        $hwp.Clear(1) | Out-Null
        Open-HwpDocument $hwp $temporary $format
        Assert-Task $hwp
    } elseif ($Mode -eq 'Inspect') {
        $xml = Read-HwpMarkup $hwp
        $xml.Save((Join-Path $output 'document.xml'))
        [IO.File]::WriteAllText((Join-Path $output 'document.txt'), [string]$hwp.GetTextFile('TEXT',''), [Text.UTF8Encoding]::new($false))
        $fields = foreach ($name in ([string]$hwp.GetFieldList(1,0)).Split([char]2)) {
            if ($name) { [ordered]@{name=$name; text=(Get-FieldValue $hwp $name)} }
        }
        $tables = foreach ($table in $xml.SelectNodes('//TABLE')) {
            $cells = foreach ($cell in $table.SelectNodes('./ROW/CELL')) {
                $attrs = [ordered]@{}; foreach ($attr in $cell.Attributes) { $attrs[$attr.Name] = $attr.Value }
                $paragraphs = foreach ($p in $cell.SelectNodes('./PARALIST/P')) {
                    -join @($p.SelectNodes('./TEXT/CHAR') | ForEach-Object { $_.InnerText })
                }
                [ordered]@{path=(Get-NodePath $cell); attributes=$attrs; paragraphs=@($paragraphs); nestedTables=$cell.SelectNodes('.//TABLE').Count}
            }
            [ordered]@{path=(Get-NodePath $table); cells=@($cells)}
        }
        Write-JsonFile ([ordered]@{source=$source; sourceSha256=$sourceHash; hancomBuild=$owner.Build; pages=[int]$hwp.PageCount; fields=@($fields); tables=@($tables)}) (Join-Path $output 'inspection.json')
    } elseif ($Mode -eq 'Render') {
        Add-Type -AssemblyName System.Drawing
        # Long documents lay out later pages lazily; CreatePageImage fails on them until the caret has
        # visited the end of the document (verified-api.md, CreatePageImage). The snapshot is never saved.
        $hwp.HAction.Run('MoveDocEnd') | Out-Null
        $count = [int]$hwp.PageCount
        $chosen = if ($Pages -and $Pages.Count) { @($Pages | Select-Object -Unique) } else { @(1..$count) }
        foreach ($page in $chosen) { if ($page -lt 1 -or $page -gt $count) { throw "Invalid page: $page; document has $count pages." } }
        $images = foreach ($page in $chosen) {
            $stem = Join-Path $output ('page-{0:D4}' -f $page)
            if (-not $hwp.CreatePageImage(($stem+'.bmp'),($page-1),$Dpi,24,'bmp')) { throw "CreatePageImage failed on page $page." }
            $bitmap = [Drawing.Image]::FromFile($stem+'.bmp')
            try { $bitmap.Save(($stem+'.png'),[Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
            Remove-Item -LiteralPath ($stem+'.bmp')
            [ordered]@{page=$page; path=($stem+'.png')}
        }
        Write-JsonFile ([ordered]@{source=$source; sourceSha256=$sourceHash; hancomBuild=$owner.Build; dpi=$Dpi; images=@($images); visuallyReviewed=$false}) (Join-Path $output 'pages.json')
    } else {
        $geometry = Get-Geometry (Read-HwpMarkup $hwp)
        if ($Mode -eq 'Fill') {
            $fieldSnapshot = Get-FieldSnapshot $hwp
            Assert-Fields $hwp $plan $false
            foreach ($entry in $plan.fields) { $hwp.PutFieldText($entry.name,$entry.text) | Out-Null }
            Assert-Fields $hwp $plan $true
            Assert-ProtectedFields $hwp $fieldSnapshot $plan
        } else { Invoke-HwpEdit -Hwp $hwp | Out-Null; Assert-Task $hwp }
        if (-not $hwp.SaveAs($temporary,$format,'')) { throw 'Save failed.' }
        $hwp.Clear(1) | Out-Null
        Open-HwpDocument $hwp $temporary $format
        if ($Mode -eq 'Fill') {
            Assert-Fields $hwp $plan $true
            Assert-ProtectedFields $hwp $fieldSnapshot $plan
        } else { Assert-Task $hwp }
        if (-not $AllowTableGeometryChange -and (Get-Geometry (Read-HwpMarkup $hwp)) -cne $geometry) { throw 'Table nesting/geometry changed; result was not published.' }
    }
    $success = $true
} finally {
    try {
        # Only the Hancom process this run started is closed; preexisting windows stay open.
        $hwp = $null
        if ($null -ne $owner) { $build = $owner.Build }
        if ((Stop-OwnedHwp $owner -ClearDocument) -eq 'terminated') { throw 'Owned Hancom did not exit normally and was stopped; output was not published.' }
        if ($source -and (Get-SharedFileHash $source) -cne $sourceHash) { throw 'Source changed; output was not published.' }
        if ($success -and $Mode -in @('Fill','Edit','Create')) { [IO.File]::Move($temporary,$output) }
    } finally {
        if ($temporary -and [IO.File]::Exists($temporary)) { Remove-Item -LiteralPath $temporary }
    }
}
Write-Output "Completed $Mode (Hancom $build): $output"
