@echo off
setlocal EnableDelayedExpansion
title HIOps Endpoint Sensor v2.0 - 自动化安装与看护配置程序

:: 1. 自动 UAC 管理员权限检测与提权
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [HIOps] 请求管理员权限以完成驱动与系统看护配置...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

echo ========================================================
echo        HIOps 医院智能信息运维平台 — 终端看护探针安装
echo ========================================================

:: 2. 系统架构与操作系统版本检测
echo [1/4] 检测操作系统架构...
set ARCH=x86
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set ARCH=x64
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set ARCH=x64
echo       当前硬件架构: %ARCH%

:: 3. 创建受保护的运行与 Spooler 缓冲目录
echo [2/4] 初始化本地取证缓冲区目录 (%ProgramData%\HIOps\spool)...
if not exist "%ProgramData%\HIOps\spool" (
    mkdir "%ProgramData%\HIOps\spool"
)

:: 4. 拷贝探针程序至安装目录
echo [3/4] 部署探针核心二进制文件至 %ProgramFiles%\HIOps\Sensor...
set INSTALL_DIR=%ProgramFiles%\HIOps\Sensor
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
copy /Y "HIOps.EndpointSensor.exe" "%INSTALL_DIR%\" >nul 2>&1
if exist "config.ini" copy /Y "config.ini" "%INSTALL_DIR%\" >nul 2>&1

:: 5. 配置 Windows Task Scheduler 自动启动与自拉起保活
echo [4/4] 注册系统级自启动看护服务 (schtasks)...
schtasks /create /tn "HIOps_Endpoint_Sensor" /tr "\"%INSTALL_DIR%\HIOps.EndpointSensor.exe\"" /sc onlogon /rl highest /f >nul 2>&1

:: 启动探针
start "" "%INSTALL_DIR%\HIOps.EndpointSensor.exe"

echo ========================================================
echo [成功] HIOps 终端智能看护探针安装配置完毕并已启动！
echo       任务栏右下角已加载运维小助手，快捷键 Ctrl+Alt+H 已生效。
echo ========================================================
timeout /t 3 >nul
exit /B 0
