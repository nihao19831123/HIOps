@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

title HIOps 终端运维小助手 — 全院批量唤醒与升级工具

echo ==============================================================================
echo       HIOps 医院智能终端看护探针 — 全院桌面小助手批量唤醒与升级脚本
echo ==============================================================================

:: 1. 结束所有旧的后台残留进程（释放 Session 0 互斥锁）
echo [1/4] 正在关闭旧的后台探针进程...
taskkill /f /im HIOps.EndpointSensor.exe >nul 2>&1

:: 2. 确保标准安装目录与配置存在
echo [2/4] 正在准备标准运行目录 (C:\Program Files\HIOps\Sensor)...
set "TARGET_DIR=%ProgramFiles%\HIOps\Sensor"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if not exist "%ProgramData%\HIOps\spool" mkdir "%ProgramData%\HIOps\spool"

:: 3. 复制最新版主程序与配置文件
echo [3/4] 正在释放最新版探针主程序 (支持会话隔离与 Ctrl+Alt+H 热键)...
if exist "%~dp0HIOps.EndpointSensor.exe" (
    copy /Y "%~dp0HIOps.EndpointSensor.exe" "%TARGET_DIR%\HIOps.EndpointSensor.exe" >nul
) else (
    echo [警告] 当前脚本同级目录下未找到 HIOps.EndpointSensor.exe！请确保文件完整。
)

if exist "%~dp0config.ini" (
    copy /Y "%~dp0config.ini" "%TARGET_DIR%\config.ini" >nul
)

:: 4. 更新 Windows 开机登录自启动计划任务
echo [4/4] 注册系统级登录自启任务 (schtasks)...
schtasks /create /tn "HIOps_Endpoint_Sensor" /tr "\"%TARGET_DIR%\HIOps.EndpointSensor.exe\"" /sc onlogon /rl highest /f >nul 2>&1

:: 5. 立即在当前桌面拉起运维小助手
echo 正在拉起桌面交互托盘与快捷键监听...
start "" "%TARGET_DIR%\HIOps.EndpointSensor.exe"

echo ==============================================================================
echo [完成] 终端看护卫士已就绪！右下角任务栏已加载 🛡️ 盾牌托盘，快捷键 Ctrl+Alt+H 已生效。
echo ==============================================================================
exit /b 0
