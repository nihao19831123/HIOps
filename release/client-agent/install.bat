@echo off
setlocal
cd /d "%~dp0"

:: 记录日志目录
if not exist "%ProgramData%\HIOps" mkdir "%ProgramData%\HIOps"
echo [%DATE% %TIME%] [install.bat] 开始执行奇安信/系统静默安装... >> "%ProgramData%\HIOps\install.log"

:: 优先调用具备全自闭环的 Setup.exe 静默模式
if exist "HIOps-EndpointSensor-Setup.exe" (
    echo [%DATE% %TIME%] [install.bat] 检测到 Setup.exe，调用静默安装模式 (/S)... >> "%ProgramData%\HIOps\install.log"
    "HIOps-EndpointSensor-Setup.exe" /S
    set EXIT_CODE=%ERRORLEVEL%
    echo [%DATE% %TIME%] [install.bat] Setup.exe 执行退出码: %EXIT_CODE% >> "%ProgramData%\HIOps\install.log"
    exit /b %EXIT_CODE%
)

:: 备用模式：直接部署
taskkill /f /im HIOps.EndpointSensor.exe >nul 2>&1
if not exist "%ProgramData%\HIOps\spool" mkdir "%ProgramData%\HIOps\spool"
set "TARGET_DIR=%ProgramFiles%\HIOps\Sensor"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

copy /Y "HIOps.EndpointSensor.exe" "%TARGET_DIR%\" >> "%ProgramData%\HIOps\install.log" 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] [install.bat] [错误] 复制 HIOps.EndpointSensor.exe 失败！ >> "%ProgramData%\HIOps\install.log"
    exit /b 1
)

schtasks /create /tn "HIOps_Endpoint_Sensor" /tr "\"%TARGET_DIR%\HIOps.EndpointSensor.exe\"" /sc onlogon /rl highest /f >> "%ProgramData%\HIOps\install.log" 2>&1
start "" "%TARGET_DIR%\HIOps.EndpointSensor.exe"
echo [%DATE% %TIME%] [install.bat] 静默安装完成。 >> "%ProgramData%\HIOps\install.log"
exit /b 0
