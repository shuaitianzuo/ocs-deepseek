$ErrorActionPreference = 'Stop'
$pidPath = Join-Path $PSScriptRoot '.server.pid'
if (-not (Test-Path -LiteralPath $pidPath)) { Write-Host 'No background process recorded.'; exit 0 }
$serviceProcessId = [int](Get-Content -LiteralPath $pidPath -Raw)
$serviceProcess = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $serviceProcessId)
$expectedScript = Join-Path $PSScriptRoot 'server.js'
if ($serviceProcess -and $serviceProcess.Name -eq 'node.exe' -and $serviceProcess.CommandLine.Contains($expectedScript)) {
    Stop-Process -Id $serviceProcessId
    Write-Host 'Service stopped.'
} elseif ($serviceProcess) {
    throw 'Recorded PID belongs to another process; it was not stopped.'
} else { Write-Host 'Service is already stopped.' }
Remove-Item -LiteralPath $pidPath
