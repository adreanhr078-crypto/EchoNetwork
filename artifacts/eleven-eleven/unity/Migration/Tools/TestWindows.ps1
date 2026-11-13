param(
    [Parameter(Mandatory)][string]$Player,
    [Parameter(Mandatory)][string]$Evidence,
    [ValidateSet('Full', 'Reduced')][string]$Motion = 'Full'
)

$ErrorActionPreference = 'Stop'
$playerPath = (Resolve-Path -LiteralPath $Player).Path
$evidencePath = [System.IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$env:ECHO_R10_CAPTURE_DIRECTORY = Join-Path $evidencePath 'captures'
$env:ECHO_R02_FIXTURE_DIRECTORY = Join-Path $evidencePath ('save-' + [guid]::NewGuid().ToString('N'))
$env:ECHO_R10_REDUCED_MOTION = if ($Motion -eq 'Reduced') { '1' } else { '0' }
$log = Join-Path $evidencePath 'player.log'
$process = Start-Process -FilePath $playerPath -WorkingDirectory (Split-Path $playerPath) -ArgumentList @(
    '-batchmode', '-force-d3d11', '-screen-width', '1280', '-screen-height', '720',
    '-screen-fullscreen', '0', '-job-worker-count', '1', '-logFile', ('"' + $log + '"')
) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'ENTRY_WINDOWS_ROUTE_PASS' -Quiet)) {
    throw "Windows route review failed. See $log"
}
Select-String -LiteralPath $log -SimpleMatch 'ENTRY_WINDOWS_ROUTE_PASS' | ForEach-Object Line
