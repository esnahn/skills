[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Inspect','Fill','Edit','Render','ValidatePlan')][string]$Mode,
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
function Write-JsonFile($Value, [string]$Path) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 40), [Text.UTF8Encoding]::new($false))
}
function Read-Markup($Hwp) {
    $xml = New-Object Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.XmlResolver = $null
    $xml.LoadXml([string]$Hwp.GetTextFile('HWPML2X',''))
    return ,$xml
}
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
if (-not $InputPath -or -not $OutputPath) { throw 'InputPath and OutputPath are required.' }
$source = (Resolve-Path -LiteralPath $InputPath).Path
if (-not [IO.File]::Exists($source) -or [IO.Path]::GetExtension($source) -ine '.hwp') { throw 'Input must be an existing .hwp file.' }
$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { throw 'Output already exists; choose a new path.' }
if (-not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($output))) { throw 'Output parent directory must exist.' }
if ($Mode -in @('Fill','Edit') -and [IO.Path]::GetExtension($output) -ine '.hwp') { throw 'Edited output must end in .hwp.' }
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess -or
    -not [Environment]::UserInteractive -or [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0 -or
    [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Use interactive Windows x64 PowerShell with -STA.' }
if (Get-Process -Name Hwp,Hwp64 -ErrorAction SilentlyContinue) { throw 'Close existing Hancom windows before this isolated operation.' }
$moduleKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\HNC\HwpAutomation\Modules',$false)
try {
    if ($null -eq $moduleKey) { throw 'Hancom security module is not registered; user setup is required.' }
    $modulePath = [string]$moduleKey.GetValue('FilePathCheckerModuleExample')
    if (-not [IO.Path]::IsPathRooted($modulePath) -or -not [IO.File]::Exists($modulePath)) { throw 'Registered security DLL is missing.' }
} finally { if ($null -ne $moduleKey) { $moduleKey.Dispose() } }
if ($Mode -eq 'Edit') {
    if (-not $TaskScript) { throw 'Edit requires TaskScript defining Invoke-HwpEdit and Test-HwpEdit.' }
    . (Resolve-Path -LiteralPath $TaskScript).Path
    foreach ($command in @('Invoke-HwpEdit','Test-HwpEdit')) {
        if (-not (Get-Command $command -CommandType Function -ErrorAction SilentlyContinue)) { throw "TaskScript must define $command." }
    }
}
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
if ($Mode -eq 'Fill' -and $sourceHash -ine $plan.sourceSha256) { throw 'Plan source hash mismatch; inspect this document again.' }
$hwp = $null; $temporary = $null; $success = $false
try {
    $openPath = $source
    if ($Mode -in @('Fill','Edit')) {
        $temporary = Join-Path ([IO.Path]::GetDirectoryName($output)) ('.hwp-edit-' + [Guid]::NewGuid().ToString('N') + '.hwp')
        [IO.File]::Copy($source,$temporary,$false); $openPath = $temporary
    } else { [IO.Directory]::CreateDirectory($output) | Out-Null }
    $hwp = New-Object -ComObject HWPFrame.HwpObject
    if (-not $hwp.RegisterModule('FilePathCheckDLL','FilePathCheckerModuleExample')) { throw 'RegisterModule failed.' }
    $hwp.XHwpWindows.Item(0).Visible = $false
    if (-not $hwp.Open($openPath,'HWP','lock:false;forceopen:true;suspendpassword:true;versionwarning:false')) { throw 'HWP open failed.' }
    if ($Mode -eq 'Inspect') {
        $xml = Read-Markup $hwp
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
        Write-JsonFile ([ordered]@{source=$source; sourceSha256=$sourceHash; pages=[int]$hwp.PageCount; fields=@($fields); tables=@($tables)}) (Join-Path $output 'inspection.json')
    } elseif ($Mode -eq 'Render') {
        Add-Type -AssemblyName System.Drawing
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
        Write-JsonFile ([ordered]@{source=$source; sourceSha256=$sourceHash; dpi=$Dpi; images=@($images); visuallyReviewed=$false}) (Join-Path $output 'pages.json')
    } else {
        $geometry = Get-Geometry (Read-Markup $hwp)
        if ($Mode -eq 'Fill') {
            $fieldSnapshot = Get-FieldSnapshot $hwp
            Assert-Fields $hwp $plan $false
            foreach ($entry in $plan.fields) { $hwp.PutFieldText($entry.name,$entry.text) | Out-Null }
            Assert-Fields $hwp $plan $true
            Assert-ProtectedFields $hwp $fieldSnapshot $plan
        } else { Invoke-HwpEdit -Hwp $hwp | Out-Null; Assert-Task $hwp }
        if (-not $hwp.SaveAs($temporary,'HWP','')) { throw 'Save failed.' }
        $hwp.Clear(1) | Out-Null
        if (-not $hwp.Open($temporary,'HWP','lock:false;forceopen:true;suspendpassword:true;versionwarning:false')) { throw 'Reopen failed.' }
        if ($Mode -eq 'Fill') {
            Assert-Fields $hwp $plan $true
            Assert-ProtectedFields $hwp $fieldSnapshot $plan
        } else { Assert-Task $hwp }
        if (-not $AllowTableGeometryChange -and (Get-Geometry (Read-Markup $hwp)) -cne $geometry) { throw 'Table nesting/geometry changed; result was not published.' }
    }
    $success = $true
} finally {
    try {
        if ($null -ne $hwp) {
            try { $hwp.Clear(1) | Out-Null } finally {
                try { $hwp.Quit() | Out-Null } finally { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($hwp) | Out-Null }
            }
        }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        $deadline = [DateTime]::UtcNow.AddSeconds(15)
        while ((Get-Process -Name Hwp,Hwp64 -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
        if (Get-Process -Name Hwp,Hwp64 -ErrorAction SilentlyContinue) { throw 'Hancom did not exit normally; output was not published.' }
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $sourceHash) { throw 'Source changed; output was not published.' }
        if ($success -and $temporary) { [IO.File]::Move($temporary,$output) }
    } finally {
        if ($temporary -and [IO.File]::Exists($temporary)) { Remove-Item -LiteralPath $temporary }
    }
}
Write-Output "Completed $Mode`: $output"
