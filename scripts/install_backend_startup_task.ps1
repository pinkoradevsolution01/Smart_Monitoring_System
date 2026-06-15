$ErrorActionPreference = 'Stop'

$taskName = 'Smart Monitoring System Backend'
$repoRoot = Split-Path -Parent $PSScriptRoot
$targetPath = Join-Path $repoRoot 'start_backend.bat'
$cmdPath = Join-Path $env:SystemRoot 'System32\cmd.exe'

if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "start_backend.bat was not found at $targetPath"
}

$action = New-ScheduledTaskAction -Execute $cmdPath -Argument "/c `"$targetPath`" --no-pause" -WorkingDirectory $repoRoot
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
} catch {
}

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

Write-Host "Created startup task:"
Write-Host "  $taskName"
Write-Host ''
Write-Host 'The backend will now start at Windows boot before you sign in.'
Write-Host 'If XAMPP MySQL is not already available at boot, start MySQL automatically too.'
