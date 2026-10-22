@echo off
chcp 65001 >nul
echo ==================================================================
echo         HIOps 医院智能信息运维平台 — Docker 容器一键启动
echo ==================================================================
cd /d "%~dp0"

echo [1/2] 正在启动 HIOps 容器栈 (PostgreSQL 16 + Web Platform)...
wsl -d Ubuntu-Local -- bash -c "cd /mnt/c/Users/wufeng/Documents/AI比赛资料/9月11日市比赛资料/docker && docker-compose up -d"

echo.
echo [2/2] 正在等待服务就绪...
timeout /t 5 >nul

echo ==================================================================
echo ✅ HIOps Docker 部署就绪！
echo 🌐 Web 控制台访问地址: http://localhost:8088
echo 👤 默认账号: admin
echo 🔑 默认密码: admin (或直接进入)
echo ==================================================================
pause
