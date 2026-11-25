# Run with pwsh -NoProfile -File so the inherited key is cleared only in this child shell.
Remove-Item Env:TRIPO_API_KEY -ErrorAction SilentlyContinue
$env:TRIPO_CLIENT_APP = 'codex'
$env:TRIPO_DISTRIBUTION_CHANNEL = 'codex_plugin'
$env:TRIPO_ANALYTICS_ENABLED = '0'
& tripo --profile echo-station @args
exit $LASTEXITCODE
