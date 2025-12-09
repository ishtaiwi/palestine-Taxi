# Script to run Flutter app from the correct directory
$frontendDir = "C:\Users\osama\Desktop\proj2\frontend"

if (-not (Test-Path $frontendDir)) {
    Write-Host "❌ Error: Frontend directory not found: $frontendDir" -ForegroundColor Red
    exit 1
}

Set-Location $frontendDir

if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ Error: pubspec.yaml not found in $frontendDir" -ForegroundColor Red
    Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Running Flutter from: $frontendDir" -ForegroundColor Green
Write-Host "✅ pubspec.yaml found" -ForegroundColor Green
Write-Host ""

flutter run -d emulator-5554

