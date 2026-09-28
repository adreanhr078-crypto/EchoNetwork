param(
    [ValidateSet('Android', 'Windows', 'All')][string]$Target = 'All',
    [string]$GodotPath = 'C:/Tools/Godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$taskApp = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskOutput = Join-Path $taskApp '.tmp/native-opening'
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskPlatforms = if ($Target -eq 'All') { @('Windows', 'Android') } else { @($Target) }
foreach ($taskPlatform in $taskPlatforms) {
    & $GodotPath --headless --path (Join-Path $taskApp 'godot') --export-debug "$taskPlatform Opening" *> (Join-Path $taskOutput ($taskPlatform.ToLower() + '-export.log'))
    if ($LASTEXITCODE -ne 0) { throw "$taskPlatform export failed; inspect its export log." }
}
if ($taskPlatforms -contains 'Android') {
    # Godot's template references an optional themed icon XML it doesn't ship.
    # Use the existing adaptive icon as a valid fallback; never change app identity.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $taskApk = Join-Path $taskOutput 'EchoNetwork-debug.apk'
    $taskZip = [IO.Compression.ZipFile]::Open($taskApk, [IO.Compression.ZipArchiveMode]::Update)
    $taskPatched = $false
    try {
        if (-not $taskZip.GetEntry('res/mipmap-anydpi-v26/themed_icon.xml')) {
            $taskIcon = $taskZip.GetEntry('res/mipmap-anydpi-v26/icon.xml')
            if (-not $taskIcon) { throw 'Adaptive launcher icon fallback is missing.' }
            $taskBuffer = [IO.MemoryStream]::new()
            $taskSource = $taskIcon.Open()
            try { $taskSource.CopyTo($taskBuffer) } finally { $taskSource.Dispose() }
            $taskBytes = $taskBuffer.ToArray()
            $taskBuffer.Dispose()
            $taskEntry = $taskZip.CreateEntry('res/mipmap-anydpi-v26/themed_icon.xml')
            $taskStream = $taskEntry.Open()
            try { $taskStream.Write($taskBytes, 0, $taskBytes.Length) } finally { $taskStream.Dispose() }
            $taskPatched = $true
        }
    } finally { $taskZip.Dispose() }
    if ($taskPatched) {
        $taskEditorSettings = Get-Content -LiteralPath (Join-Path (Split-Path $GodotPath) 'editor_data/editor_settings-4.7.tres') -Raw
        function Read-TaskSetting([string]$Key) {
            $taskMatch = [regex]::Match($taskEditorSettings, '(?m)^' + [regex]::Escape($Key) + ' = "([^"]*)"')
            if (-not $taskMatch.Success) { throw "Missing local editor setting: $Key" }
            return $taskMatch.Groups[1].Value.Replace('\\', '\')
        }
        $taskSdk = Read-TaskSetting 'export/android/android_sdk_path'
        $taskJava = Read-TaskSetting 'export/android/java_sdk_path'
        $taskKeystore = Read-TaskSetting 'export/android/debug_keystore'
        $taskBuildTools = Join-Path $taskSdk 'build-tools/36.0.0'
        $taskAligned = Join-Path $taskOutput 'EchoNetwork-debug.aligned.apk'
        & (Join-Path $taskBuildTools 'zipalign.exe') -f -p 4 $taskApk $taskAligned
        if ($LASTEXITCODE -ne 0) { throw 'APK alignment failed.' }
        Move-Item -LiteralPath $taskAligned -Destination $taskApk -Force
        $taskPriorJava = $env:JAVA_HOME
        $taskPriorPassword = $env:ECHO_ANDROID_DEBUG_SIGN_PASSWORD
        try {
            $env:JAVA_HOME = $taskJava
            $env:ECHO_ANDROID_DEBUG_SIGN_PASSWORD = Read-TaskSetting 'export/android/debug_keystore_pass'
            & (Join-Path $taskBuildTools 'apksigner.bat') sign --ks $taskKeystore --ks-pass env:ECHO_ANDROID_DEBUG_SIGN_PASSWORD --ks-key-alias androiddebugkey $taskApk
            if ($LASTEXITCODE -ne 0) { throw 'APK signing failed.' }
            & (Join-Path $taskBuildTools 'apksigner.bat') verify $taskApk
            if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
        } finally {
            $env:JAVA_HOME = $taskPriorJava
            $env:ECHO_ANDROID_DEBUG_SIGN_PASSWORD = $taskPriorPassword
        }
    }
}
Get-ChildItem -LiteralPath $taskOutput -File | Where-Object Extension -in '.apk', '.pck', '.exe' | Select-Object Name, Length
