param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($CheckOnly) {
    Get-Command node.exe -ErrorAction Stop | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'server.js'))) { throw 'server.js missing' }
    Write-Host 'Launcher check passed: PowerShell and Node.js are available.'
    exit 0
}
$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path -LiteralPath $envPath)) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot '.env.example') -Destination $envPath }
$configText = Get-Content -LiteralPath $envPath -Raw -Encoding UTF8
if ($configText -match '(?m)^DEEPSEEK_API_KEY=[ \t]*\r?$') {
    Write-Host '请输入 DeepSeek API Key（输入内容不显示，仅保存在本地 .env）'
    $secret = Read-Host -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try {
        $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr).Trim()
        if ([string]::IsNullOrWhiteSpace($key) -or $key -match '[\r\n]') { throw 'API Key 不能为空或包含换行。' }
        $configText = [regex]::Replace($configText, '(?m)^DEEPSEEK_API_KEY=[ \t]*\r?$', ('DEEPSEEK_API_KEY=' + $key))
        [IO.File]::WriteAllText($envPath, $configText, (New-Object Text.UTF8Encoding($false)))
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        $key = $null
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'node_modules/express'))) {
    & npm.cmd ci --ignore-scripts
    if ($LASTEXITCODE -ne 0) { throw '依赖安装失败，请检查网络后重试。' }
}
$portMatch = [regex]::Match($configText, '(?m)^OCS_PORT=(\d+)')
$port = if ($portMatch.Success) { [int]$portMatch.Groups[1].Value } else { 3000 }
$serviceUrl = 'http://127.0.0.1:' + $port
$logDir = if ($env:OCS_LOG_DIR) { $env:OCS_LOG_DIR } elseif (Test-Path 'D:\') { 'D:\CodexData\Logs\ocs-deepseek' } else { Join-Path $PSScriptRoot 'logs' }
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
try {
    $info = Invoke-RestMethod ($serviceUrl + '/info') -TimeoutSec 2
    if ($info.code -eq 1 -and $info.provider -eq 'deepseek') {
        Write-Host '本地服务已在运行。'
        Read-Host '按回车关闭'
        exit
    }
    throw '端口 3000 已被其他服务占用。'
} catch [System.Net.WebException] {
}
$nodePath = (Get-Command node.exe).Source
$child = Start-Process -PassThru -FilePath $nodePath -ArgumentList ('"' + (Join-Path $PSScriptRoot 'server.js') + '"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDir 'server.log') -RedirectStandardError (Join-Path $logDir 'error.log')
$child.Id | Set-Content -LiteralPath (Join-Path $PSScriptRoot '.server.pid') -Encoding ASCII
Start-Sleep -Seconds 2
$status = Invoke-RestMethod ($serviceUrl + '/info') -TimeoutSec 5
if ($status.code -ne 1) { throw '启动失败，请查看日志。' }
Write-Host ('服务已启动：' + $serviceUrl)
Write-Host '请将同目录 OCS题库配置.json 的全部内容粘贴到 OCS 自定义题库配置中。'
Read-Host '按回车关闭（服务会继续后台运行）'
