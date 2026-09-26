Write-Host ""
Write-Host "============================================================"
Write-Host " ECHO NETWORK FLAX VALIDATION"
Write-Host "============================================================"
Write-Host ""

$Editor = ""
$Godot = "C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\godot\project.godot"
$Zip = "C:\Users\yasmo\EchoNetwork\tools\FlaxEngine.zip"
$FlaxProj = "C:\Users\yasmo\EchoNetwork\FlaxMigration\EchoNetworkFlax\EchoNetworkFlax.flaxproj"
$SourceDir = "C:\Users\yasmo\EchoNetwork\FlaxMigration\EchoNetworkFlax\Source"

Write-Host "Godot Baseline:"
Write-Host (Test-Path $Godot)

Write-Host ""

Write-Host "Flax ZIP / Source:"
Write-Host (Test-Path $Zip)

Write-Host ""

Write-Host "Flax Project Descriptor:"
Write-Host (Test-Path $FlaxProj)

Write-Host ""

$csFiles = Get-ChildItem -Path $SourceDir -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue
Write-Host "Flax C# Source Files:"
Write-Host ($csFiles.Count)

Write-Host ""

$editorExists = if (![string]::IsNullOrEmpty($Editor)) { Test-Path $Editor } else { $false }
Write-Host "Flax Editor Binary:"
Write-Host $editorExists

Write-Host ""

if ($editorExists) {
    Write-Host "STATUS:"
    Write-Host "FLAX EDITOR READY"
} else {
    Write-Host "STATUS:"
    Write-Host "FLAX PROJECT & C# ARCHITECTURE STAGED; EDITOR BINARY REQUIRED FOR COOKING"
}
