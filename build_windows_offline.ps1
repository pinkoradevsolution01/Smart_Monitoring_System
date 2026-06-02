Write-Host "Building Windows (No Firebase)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Remove Firebase from pubspec temporarily
Write-Host "Step 1: Removing Firebase dependencies..." -ForegroundColor Yellow
$pubspec = Get-Content pubspec.yaml -Raw
$pubspecBackup = $pubspec
$pubspec = $pubspec -replace "(?ms)# Firebase.*?google_sign_in: 6\.2\.1", "# Firebase removed for Windows build"
Set-Content -Path pubspec.yaml -Value $pubspec
Write-Host "Firebase removed from pubspec.yaml" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2: Cleaning build..." -ForegroundColor Yellow
flutter clean
Write-Host ""

Write-Host "Step 3: Removing cached files..." -ForegroundColor Yellow
if (Test-Path "build") { Remove-Item -Path "build" -Recurse -Force }
if (Test-Path "windows\flutter\ephemeral") { Remove-Item -Path "windows\flutter\ephemeral" -Recurse -Force }
Write-Host "Cache cleaned" -ForegroundColor Green
Write-Host ""

Write-Host "Step 4: Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host ""

Write-Host "Step 5: Building Windows..." -ForegroundColor Yellow
flutter build windows --release
$buildSuccess = $LASTEXITCODE -eq 0
Write-Host ""

Write-Host "Step 6: Restoring original pubspec..." -ForegroundColor Yellow
Set-Content -Path pubspec.yaml -Value $pubspecBackup
flutter pub get | Out-Null
Write-Host "Original pubspec restored" -ForegroundColor Green
Write-Host ""

if ($buildSuccess) {
    Write-Host "========================================"  -ForegroundColor Green
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your app is ready at:" -ForegroundColor Cyan
    Write-Host "build\windows\x64\runner\Release\smart_monitoring_system.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "NOTE: This build runs in OFFLINE MODE" -ForegroundColor Yellow
    Write-Host "Firebase features are disabled" -ForegroundColor Yellow
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
