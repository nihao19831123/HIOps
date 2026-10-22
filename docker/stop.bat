@echo off
chcp 65001 >nul
echo 正在停止 HIOps 容器...
wsl -d Ubuntu-Local -- bash -c "cd /mnt/c/Users/wufeng/Documents/AI比赛资料/9月11日市比赛资料/docker && docker-compose down"
echo.
echo ✅ HIOps 容器已安全停止。
pause
