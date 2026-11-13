param(
    [Parameter(Mandatory)][string]$Unity,
    [Parameter(Mandatory)][string]$Output,
    [string]$Project = (Join-Path $PSScriptRoot '../..'),
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath $Project).Path
$editor = (Resolve-Path -LiteralPath $Unity).Path
$env:ECHO_ENTRY_EXPORT_PATH = [System.IO.Path]::GetFullPath($Output)
$env:ECHO_ENTRY_VERIFY = if ($Verify) { '1' } else { '0' }
$env:ECHO_ENTRY_REBUILD = '0'
$env:ECHO_ENTRY_ROOM = '0'
$log = Join-Path ([System.IO.Path]::GetDirectoryName($env:ECHO_ENTRY_EXPORT_PATH)) 'unity-build.log'
New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($log)) -Force | Out-Null
$process = Start-Process -FilePath $editor -ArgumentList @(
    '-batchmode', '-nographics', '-job-worker-count', '1',
    '-projectPath', ('"' + $projectPath + '"'),
    '-executeMethod', 'ElevenEleven.Editor.EntryWindowsBuild.Run',
    '-logFile', ('"' + $log + '"')
) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'ENTRY_WINDOWS_BUILD_PASS' -Quiet)) {
    throw "Windows export failed. See $log"
}
Select-String -LiteralPath $log -SimpleMatch 'ENTRY_WINDOWS_BUILD_PASS' | ForEach-Object Line
