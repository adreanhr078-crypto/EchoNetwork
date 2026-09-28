param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$taskRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskMirrorPrefix = 'FlaxMigration/SourceAssets/'
$taskMirrorRoot = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $taskMirrorPrefix))
$taskManifestPath = Join-Path $taskRoot 'artifacts/eleven-eleven/docs/internal/production/2026-09-28-cleanup-manifest.json'
if (Test-Path -LiteralPath $taskManifestPath) {
    $taskPrior = Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
    if ($taskPrior.mode -eq 'applied') { throw 'Applied recovery ledger already exists; preserve it instead of overwriting this historical cleanup.' }
}
$taskTracked = @(& git -C $taskRoot -c core.quotepath=false ls-files)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory tracked files.' }
$taskCanonical = @{}
foreach ($taskRelative in $taskTracked) {
    if ($taskRelative.StartsWith('FlaxMigration/')) { continue }
    $taskAbsolute = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $taskRelative))
    if (-not (Test-Path -LiteralPath $taskAbsolute -PathType Leaf)) { continue }
    $taskInfo = Get-Item -LiteralPath $taskAbsolute
    $taskSize = [string]$taskInfo.Length
    if (-not $taskCanonical.ContainsKey($taskSize)) { $taskCanonical[$taskSize] = [System.Collections.Generic.List[string]]::new() }
    $taskCanonical[$taskSize].Add($taskRelative)
}
$taskHashes = @{}
function Get-TaskHash([string]$Relative) {
    if (-not $taskHashes.ContainsKey($Relative)) {
        $taskHashes[$Relative] = (Get-FileHash -LiteralPath (Join-Path $taskRoot $Relative) -Algorithm SHA256).Hash
    }
    return $taskHashes[$Relative]
}
$taskEntries = [System.Collections.Generic.List[object]]::new()
$taskRetained = 0
foreach ($taskRelative in $taskTracked) {
    if (-not $taskRelative.StartsWith($taskMirrorPrefix)) { continue }
    $taskAbsolute = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $taskRelative))
    if (-not (Test-Path -LiteralPath $taskAbsolute -PathType Leaf)) { continue }
    $taskSize = [string](Get-Item -LiteralPath $taskAbsolute).Length
    $taskCounterpart = $taskRelative.Substring($taskMirrorPrefix.Length)
    $taskCandidates = @()
    if ($taskTracked -contains $taskCounterpart -and (Test-Path -LiteralPath (Join-Path $taskRoot $taskCounterpart) -PathType Leaf)) {
        $taskCandidates += $taskCounterpart
    }
    if ($taskCanonical.ContainsKey($taskSize)) { $taskCandidates += $taskCanonical[$taskSize] }
    $taskHash = Get-TaskHash $taskRelative
    $taskMatch = $null
    foreach ($taskCandidate in ($taskCandidates | Select-Object -Unique)) {
        if ((Get-TaskHash $taskCandidate) -eq $taskHash) { $taskMatch = $taskCandidate; break }
    }
    if ($null -eq $taskMatch) { $taskRetained++; continue }
    $taskEntries.Add([ordered]@{ removed = $taskRelative; retained = $taskMatch; sha256 = $taskHash; bytes = [long]$taskSize })
}
$taskTotalBytes = 0L
foreach ($taskEntry in $taskEntries) { $taskTotalBytes += [long]$taskEntry['bytes'] }
$taskManifest = [ordered]@{
    version = 1; mode = $(if ($Apply) { 'applied' } else { 'preview' }); baseCommit = (& git -C $taskRoot rev-parse HEAD)
    purpose = 'Remove byte-identical copies from the abandoned Flax source mirror; retain every canonical original and every unique mirror file.'
    duplicateFiles = $taskEntries.Count; uniqueMirrorFilesRetained = $taskRetained
    bytesRemoved = $taskTotalBytes
    backup = $null; entries = $taskEntries.ToArray()
}
if ($Apply -and $taskEntries.Count -gt 0) {
    # Verify all resolved deletion paths and retained originals before any mutation.
    foreach ($taskEntry in $taskEntries) {
        $taskAbsolute = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $taskEntry.removed))
        if (-not $taskAbsolute.StartsWith($taskMirrorRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Deletion outside migration mirror refused.' }
        if ((Get-FileHash -LiteralPath $taskAbsolute -Algorithm SHA256).Hash -ne $taskEntry.sha256) { throw 'Mirror changed after inventory.' }
        if ((Get-FileHash -LiteralPath (Join-Path $taskRoot $taskEntry.retained) -Algorithm SHA256).Hash -ne $taskEntry.sha256) { throw 'Retained original changed after inventory.' }
    }
    $taskBackupDir = Join-Path $env:USERPROFILE '.codex/backups/EchoNetwork'
    New-Item -ItemType Directory -Path $taskBackupDir -Force | Out-Null
    $taskBackup = Join-Path $taskBackupDir ('migration-duplicates-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $taskZip = [System.IO.Compression.ZipFile]::Open($taskBackup, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($taskEntry in $taskEntries) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskZip, (Join-Path $taskRoot $taskEntry.removed), $taskEntry.removed, [System.IO.Compression.CompressionLevel]::Fastest) | Out-Null
        }
    } finally { $taskZip.Dispose() }
    $taskManifest.backup = $taskBackup
    # Save the recovery inventory before deleting; use only native PowerShell paths.
    $taskManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $taskManifestPath -Encoding utf8
    foreach ($taskEntry in $taskEntries) {
        Remove-Item -LiteralPath ([System.IO.Path]::GetFullPath((Join-Path $taskRoot $taskEntry.removed)))
    }
} else {
    $taskManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $taskManifestPath -Encoding utf8
}
[pscustomobject]@{ Mode = $taskManifest.mode; DuplicateFiles = $taskEntries.Count; UniqueMirrorFilesRetained = $taskRetained; MiB = [math]::Round($taskManifest.bytesRemoved / 1MB, 2); Manifest = $taskManifestPath; Backup = $taskManifest.backup } | Format-List
