$ErrorActionPreference = "Continue"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Log = Join-Path 
    "C:\Users\yasmo\EchoNetwork\FlaxMigration\Logs" 
    "FlaxTest_$Timestamp.log"

Write-Host ""
Write-Host "==============================================="
Write-Host " ECHO NETWORK FLAX TEST"
Write-Host "==============================================="
Write-Host ""

$Editor = ""

$Project = "C:\Users\yasmo\EchoNetwork\FlaxMigration\EchoNetworkFlax"


if (!(Test-Path $Editor))
{
    "Flax Editor missing." |
        Tee-Object -FilePath $Log

    exit 2
}


try
{
    & $Editor 
        -project "$Project" 
        *>&1 |
        Tee-Object 
            -FilePath $Log

}
catch
{
    $_ |
        Out-String |
        Tee-Object 
            -FilePath $Log 
            -Append

    exit 1
}


Write-Host ""
Write-Host "Log:"
Write-Host $Log

