param(
    [Parameter(Mandatory=$true)][string]$ModelUrl,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [string]$Sha256
)

$ErrorActionPreference = 'Stop'

$destDir = Split-Path -Parent $OutPath
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

Write-Host "Downloading model from $ModelUrl" -ForegroundColor Cyan
Invoke-WebRequest -Uri $ModelUrl -OutFile $OutPath

if ($Sha256) {
    Write-Host "Verifying SHA-256 checksum" -ForegroundColor Cyan
    $hash = Get-FileHash -Algorithm SHA256 -Path $OutPath
    if ($hash.Hash.ToLower() -ne $Sha256.ToLower()) {
        Remove-Item $OutPath -ErrorAction SilentlyContinue
        throw "Checksum mismatch. Expected $Sha256 but got $($hash.Hash)."
    }
    Write-Host "Checksum OK" -ForegroundColor Green
}

Write-Host "Model saved to $OutPath" -ForegroundColor Green
