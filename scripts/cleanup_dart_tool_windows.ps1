<#
Attempts to stop common Dart/Flutter processes that may lock files
and removes the .dart_tool directory. Run from project root.
#>
param(
    [switch]$Force
)

Write-Host "Attempting to stop common Dart/Flutter processes..."

$procs = @('dart','dart.exe','dartanalyzer','dartanalyzer.exe','flutter','flutter_tester','pub','pub.exe')
foreach ($p in $procs) {
    try {
        $found = Get-Process -Name $p -ErrorAction SilentlyContinue
        if ($found) {
            Write-Host "Stopping process(es): $p"
            $found | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # ignore
    }
}

Write-Host "Waiting a moment for processes to exit..."
Start-Sleep -Seconds 1

$target = Join-Path -Path (Get-Location) -ChildPath '.dart_tool'
if (-not (Test-Path $target)) {
    Write-Host ".dart_tool not found at: $target"
    exit 0
}

try {
    Write-Host "Removing $target ..."
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
    Write-Host "Removed .dart_tool successfully."
} catch {
    Write-Host "Failed to remove .dart_tool: $($_.Exception.Message)"
    if (-not $Force) {
        Write-Host "Common causes: editors (VS Code), terminals, or background Dart/Flutter processes are locking files."
        Write-Host "Try these steps:"
        Write-Host "  1) Close editors (VS Code) and any terminals running Flutter/Dart."
        Write-Host "  2) Re-run this script with the -Force flag to attempt again."
        Write-Host "  3) If still blocked, reboot the machine or use Sysinternals 'Handle'/'Process Explorer' to find the lock."
    } else {
        Write-Host "-Force was supplied but removal still failed. Consider rebooting or using Sysinternals tools."
    }
    exit 1
}

Write-Host "Running 'flutter clean' to clear additional artifacts..."
flutter clean

Write-Host "Done. You can now run 'flutter build windows' or 'flutter run -d windows'."
