@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title HIOps 终端探针故障与下发诊断工具
color 0F

echo ==============================================================================
echo       HIOps 医院智能终端看护探针 (Endpoint Sensor) — 下发故障诊断工具
echo ==============================================================================
echo 当前测试主机名: %COMPUTERNAME%
echo 当前测试时间  : %DATE% %TIME%
echo.

set FAIL_COUNT=0

:: 1. 检查管理员权限
echo [1/6] 检查管理员提权状态...
net session >nul 2>&1
if %errorlevel% == 0 (
    echo       [通过] 具备本地系统管理员权限。
) else (
    echo       [警告] 当前未以管理员身份运行，可能无法查看系统服务或任务计划！
)

:: 2. 检查 .NET Framework 运行时
echo.
echo [2/6] 检查 .NET Framework 运行时版本...
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release >nul 2>&1
if %errorlevel% == 0 (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2^>nul') do set /a REL=%%a
    echo       检测到 .NET 4.x 注册表版本号: !REL!
    if !REL! GEQ 394802 (
        echo       [通过] 已安装 .NET Framework 4.6.2 / 4.7 / 4.8 及以上版本。
    ) else (
        echo       [失败] 本机 .NET Framework 版本低于 4.6 (Release: !REL!)，需打 .NET 4.8 离线补丁！
        set /a FAIL_COUNT+=1
    )
) else (
    echo       [失败] 未检测到 .NET Framework 4.0 以上完整运行时！
    set /a FAIL_COUNT+=1
)

:: 3. 检查文件释放情况
echo.
echo [3/6] 检查探针文件部署路径 (C:\Program Files\HIOps\Sensor)...
if exist "%ProgramFiles%\HIOps\Sensor\HIOps.EndpointSensor.exe" (
    for %%F in ("%ProgramFiles%\HIOps\Sensor\HIOps.EndpointSensor.exe") do echo       [通过] 主程序已释放，大小: %%~zF 字节。
) else (
    echo       [失败] 目标目录未找到 HIOps.EndpointSensor.exe 文件！下发过程可能未执行或被拦截。
    set /a FAIL_COUNT+=1
)

:: 4. 检查自启动计划任务
echo.
echo [4/6] 检查 Windows 开机自启计划任务 (schtasks)...
schtasks /query /tn "HIOps_Endpoint_Sensor" >nul 2>&1
if %errorlevel% == 0 (
    echo       [通过] 任务计划 HIOps_Endpoint_Sensor 已成功注册。
) else (
    echo       [失败] 任务计划未找到！可能安装脚本未完成或被安全软件阻止写入。
    set /a FAIL_COUNT+=1
)

:: 5. 检查探针进程运行状态
echo.
echo [5/6] 检查探针后台进程 (HIOps.EndpointSensor.exe)...
tasklist /fi "imagename eq HIOps.EndpointSensor.exe" | find /i "HIOps.EndpointSensor.exe" >nul 2>&1
if %errorlevel% == 0 (
    echo       [通过] 探针进程正在后台常驻运行中。
) else (
    echo       [失败] 探针当前未在运行！尝试手动启动...
    if exist "%ProgramFiles%\HIOps\Sensor\HIOps.EndpointSensor.exe" (
        start "" "%ProgramFiles%\HIOps\Sensor\HIOps.EndpointSensor.exe"
        timeout /t 2 >nul
        tasklist /fi "imagename eq HIOps.EndpointSensor.exe" | find /i "HIOps.EndpointSensor.exe" >nul 2>&1
        if !errorlevel! == 0 (
            echo       [恢复] 手动拉起探针成功！
        ) else (
            echo       [失败] 手动拉起探针失败，请检查杀软拦截或事件查看器日志。
            set /a FAIL_COUNT+=1
        )
    )
)

:: 6. 检查网络与中台连通性 (192.168.114.30:5080)
echo.
echo [6/6] 检查到 HIOps 生产中台的网络出站连通性 (192.168.114.30:5080)...
curl.exe -s --connect-timeout 4 http://192.168.114.30:5080/api/health > "%temp%\hiops_health.tmp" 2>&1
if %errorlevel% == 0 (
    findstr /i "success" "%temp%\hiops_health.tmp" >nul 2>&1
    if !errorlevel! == 0 (
        echo       [通过] 成功连接至 HIOps 平台 API (HTTP 200 OK)。
    ) else (
        echo       [提示] 端口可达，平台响应: 
        type "%temp%\hiops_health.tmp"
    )
) else (
    echo       [失败] 无法连通 192.168.114.30:5080！当前网段出站策略被防火墙阻断或路由不可达。
    set /a FAIL_COUNT+=1
)
if exist "%temp%\hiops_health.tmp" del "%temp%\hiops_health.tmp"

:: 7. 输出最近安装日志 (若存在)
echo.
echo ==============================================================================
echo 最近安装日志摘要 (C:\ProgramData\HIOps\install.log):
echo ==============================================================================
if exist "%ProgramData%\HIOps\install.log" (
    powershell -Command "Get-Content '%ProgramData%\HIOps\install.log' -Tail 15"
) else (
    if exist "%temp%\hiops_install.log" (
        powershell -Command "Get-Content '%temp%\hiops_install.log' -Tail 15"
    ) else (
        echo [无本地日志] 尚未在本地生成 install.log，说明安装包未曾真正运行。
    )
)

echo.
echo ==============================================================================
if %FAIL_COUNT% == 0 (
    color 0A
    echo [诊断结果] 终端探针完全正常！各项检查 100%% 通过。
) else (
    color 0C
    echo [诊断结果] 发现 %FAIL_COUNT% 项异常，请参考上方标记为 [失败] 的项目进行排查。
)
echo ==============================================================================
echo 按任意键退出诊断程序...
pause >nul
