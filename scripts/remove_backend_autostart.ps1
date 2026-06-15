$ErrorActionPreference = 'Stop'

$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder 'Smart Monitoring System Backend.lnk'

if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
    Write-Host "Removed startup shortcut:"
    Write-Host "  $shortcutPath"
} else {
    Write-Host "No startup shortcut found at:"
    Write-Host "  $shortcutPath"
}
