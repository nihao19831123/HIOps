# ==============================================================================
# HIOps 医院智能运维平台 — 内网极速增量补丁一键打包程序
# ==============================================================================

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "          HIOps 医院智能运维平台 — 内网极速增量补丁一键打包程序               " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TempDir = Join-Path $ScriptDir "patch_staging"
$OutputFile = Join-Path $ScriptDir "HIOps-Patch-Latest.tar.gz"

if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}
New-Item -ItemType Directory -Path $TempDir | Out-Null

Write-Host "[1/3] 正在收集最新业务核心组件与前端页面..." -ForegroundColor Yellow
Copy-Item "$ScriptDir\api\HIOps*.dll" "$TempDir\" -Force
if (Test-Path "$ScriptDir\api\HIOps.Api") {
    Copy-Item "$ScriptDir\api\HIOps.Api" "$TempDir\" -Force
}
if (Test-Path "$ScriptDir\wwwroot") {
    Copy-Item "$ScriptDir\wwwroot" "$TempDir\" -Recurse -Force
}
if (Test-Path "$ScriptDir\apply_patch.sh") {
    Copy-Item "$ScriptDir\apply_patch.sh" "$TempDir\" -Force
}
if (Test-Path "$ScriptDir\patch.sql") {
    Write-Host "[提示] 检测到可选数据库补丁 patch.sql，一并纳入补丁包..." -ForegroundColor Magenta
    Copy-Item "$ScriptDir\patch.sql" "$TempDir\" -Force
}

Write-Host "[2/3] 正在使用 tar 压缩生成超轻量补丁包 (约 1.8MB)..." -ForegroundColor Yellow
Push-Location $TempDir
try {
    tar.exe -czf $OutputFile *
} finally {
    Pop-Location
}

Remove-Item -Recurse -Force $TempDir

$FileItem = Get-Item $OutputFile
$SizeMB = [math]::Round($FileItem.Length / 1MB, 2)

Write-Host "[3/3] 打包完成！" -ForegroundColor Green
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "  * 极速热补丁包已成功生成！" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "  * 补丁包文件: $OutputFile" -ForegroundColor White
Write-Host "  * 压缩包大小: $SizeMB MB (极小极快，仅包含业务代码与前端，无需拷系统环境)" -ForegroundColor White
Write-Host ""
Write-Host "  * 内网升级只需 2 步 (耗时 3~5 秒):" -ForegroundColor Cyan
Write-Host "      1. 将 HIOps-Patch-Latest.tar.gz 拷入内网服务器并解压:" -ForegroundColor White
Write-Host "         tar -zxvf HIOps-Patch-Latest.tar.gz" -ForegroundColor Yellow
Write-Host "      2. 运行热更脚本 (保留内网现有配置与数据，全自动备份与重启生效):" -ForegroundColor White
Write-Host "         bash apply_patch.sh" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host ""