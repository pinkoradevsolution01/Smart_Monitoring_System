$ErrorActionPreference = 'Stop'

$taskName = 'Smart Monitoring System Backend'

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
    Write-Host "Removed startup task:"
    Write-Host "  $taskName"
} catch {
    Write-Host "No startup task found:"
    Write-Host "  $taskName"
}
