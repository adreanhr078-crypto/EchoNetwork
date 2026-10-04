param(
    [string]$GodotPath = 'C:/Tools/Godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe',
    [string]$OutputDirectory = '.tmp/third-person-foundation'
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$taskApp = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $taskApp $OutputDirectory }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot console executable not found: $GodotPath" }
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskCases = @(
    @{ Name = 'controls'; Script = 'third_person_controls_smoke'; Args = @() },
    @{ Name = 'boundaries'; Script = 'controller_boundaries_smoke'; Args = @() },
    @{ Name = 'camera'; Script = 'third_person_camera_smoke'; Args = @() },
    @{ Name = 'native-foundation'; Script = 'player_foundation_smoke'; Args = @() },
    @{ Name = 'pause-touch'; Script = 'native_pause_touch_smoke'; Args = @() },
    @{ Name = 'opening'; Script = 'opening_slice_smoke'; Args = @() },
    @{ Name = 'opening-maintenance-route'; Script = 'opening_route_input_smoke'; Args = @() },
    @{ Name = 'maintenance-traversal'; Script = 'maintenance_traversal_smoke'; Args = @() },
    @{ Name = 'traversal-reliability'; Script = 'traversal_reliability_smoke'; Args = @() },
    @{ Name = 'platform-60s'; Script = 'traversal_platform_smoke'; Args = @() },
    @{ Name = 'platform-actions'; Script = 'traversal_platform_actions_smoke'; Args = @() },
    @{ Name = 'service-natural'; Script = 'maintenance_service_smoke'; Args = @() },
    @{ Name = 'service-skip'; Script = 'maintenance_service_smoke'; Args = @('--skip') },
    @{ Name = 'service-reduced'; Script = 'maintenance_service_smoke'; Args = @('--reduced') },
    @{ Name = 'maintenance-checkpoint'; Script = 'maintenance_checkpoint_smoke'; Args = @() },
    @{ Name = 'frame-capture-opt-in'; Script = 'player_frame_capture_smoke'; Args = @('--echo-frame-capture') }
)
$taskResults = @()
foreach ($taskCase in $taskCases) {
    $taskLog = Join-Path $taskOutput ($taskCase.Name + '.log')
    $taskArguments = @('--headless', '--path', (Join-Path $taskApp 'godot'), '--script', ('res://tests/' + $taskCase.Script + '.gd'))
    if ($taskCase.Args.Count -gt 0) { $taskArguments += @('--') + $taskCase.Args }
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    cmd /c "`"$GodotPath`" $($taskArguments -join ' ') > `"$taskLog`" 2>&1"
    $taskExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    $taskText = Get-Content -LiteralPath $taskLog -Raw
    # Godot can exit 0 after a parse/runtime error. Require both clean engine
    # diagnostics and the test's explicit verdict, not just process success.
    $taskPassed = $taskExit -eq 0 -and $taskText -match '(?m)^PASS' -and $taskText -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)'
    $taskResults += [ordered]@{ name = $taskCase.Name; script = $taskCase.Script; arguments = $taskCase.Args; exitCode = $taskExit; status = $(if ($taskPassed) { 'PASS' } else { 'FAIL' }); log = $taskLog }
    $taskResults | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskOutput 'results.json') -Encoding utf8
    Get-Content -LiteralPath $taskLog -Tail 6
    if (-not $taskPassed) { throw "Foundation test failed: $($taskCase.Name). Inspect $taskLog" }
}
Write-Output "PASS third-person foundation: $($taskResults.Count) cases. Headless results do not certify visuals or a physical phone."
