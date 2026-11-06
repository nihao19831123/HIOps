@echo off
chcp 65001 >nul
title HIOps Endpoint Sensor - 终端卸载程序

:: 1. 自动管理员权限提权
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [HIOps] 正在请求管理员权限以卸载服务...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B
)
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )

echo ========================================================
echo        HIOps 医院智能信息运维平台 — 终端探针卸载
echo ========================================================

echo [1/3] 正在停止运行中的探针进程...
taskkill /f /im HIOps.EndpointSensor.exe >nul 2>&1

echo [2/3] 注销计划任务开机自启 (schtasks)...
schtasks /delete /tn "HIOps_Endpoint_Sensor" /f >nul 2>&1

echo [3/3] 清理安装文件与本地缓存目录...
if exist "%ProgramFiles%\HIOps" (
    rd /s /q "%ProgramFiles%\HIOps" >nul 2>&1
)
if exist "%ProgramData%\HIOps\spool" (
    rd /s /q "%ProgramData%\HIOps\spool" >nul 2>&1
)

echo ========================================================
echo [成功] HIOps 终端探针已完全卸载并清理完毕！
echo ========================================================
timeout /t 3 >nul
exit /B 0
