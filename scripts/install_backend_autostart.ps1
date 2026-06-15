$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder 'Smart Monitoring System Backend.lnk'
$targetPath = Join-Path $repoRoot 'start_backend.bat'

if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "start_backend.bat was not found at $targetPath"
}

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:SystemRoot\System32\cmd.exe"
$shortcut.Arguments = "/c `"$targetPath`" --no-pause"
$shortcut.WorkingDirectory = $repoRoot
$shortcut.WindowStyle = 7
$shortcut.Description = 'Start Smart Monitoring System backend at Windows sign-in'
$shortcut.Save()

Write-Host "Created startup shortcut:"
Write-Host "  $shortcutPath"
Write-Host ''
Write-Host 'The backend will now start automatically when you sign in to Windows.'
Write-Host 'If MySQL is also handled by XAMPP, make sure XAMPP/MySQL starts first or is set to auto-start too.'
