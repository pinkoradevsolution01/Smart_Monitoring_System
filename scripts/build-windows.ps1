param(
    [string]$Configuration = "Debug"
)

Write-Host "Stopping running app if present..."
$procs = Get-Process -Name smart_monitoring_system -ErrorAction SilentlyContinue
if ($procs) {
    foreach ($p in $procs) {
        Write-Host "Killing PID $($p.Id)"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "No running instance found."
}

Write-Host "Running: flutter build windows -v --${Configuration.ToLower()}"
flutter build windows -v --$($Configuration.ToLower())
