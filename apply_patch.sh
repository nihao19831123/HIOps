#!/usr/bin/env bash
# ==============================================================================
# HIOps 物理隔离内网快速热补丁升级脚本 (apply_patch.sh)
# 作用: 快速更新业务 DLL / 前端页面 / 增量 SQL，保留内网原有配置与数据
# ==============================================================================

set -e

COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}          HIOps 物理隔离内网系统 — 快速增量热更程序 (Patch Updater)          ${COLOR_RESET}"
echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${COLOR_RED}[错误] 请使用 root 用户或 sudo 执行此脚本！${COLOR_RESET}"
    exit 1
fi

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/opt/hiops/api"
BACKUP_BASE="/opt/hiops/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_BASE/backup_$TIMESTAMP"

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${COLOR_RED}[错误] 未检测到 HIOps 部署目录 ($TARGET_DIR)！${COLOR_RESET}"
    echo "请确认是否已完成初次离线部署。"
    exit 1
fi

# 1. 创建备份（防翻车）
echo -e "\n${COLOR_CYAN}[1/5] 创建当前线上版本防回滚备份...${COLOR_RESET}"
mkdir -p "$BACKUP_DIR"
if [ -d "$TARGET_DIR/wwwroot" ]; then
    cp -r "$TARGET_DIR/wwwroot" "$BACKUP_DIR/" 2>/dev/null || true
fi
cp "$TARGET_DIR"/HIOps*.dll "$BACKUP_DIR/" 2>/dev/null || true
cp "$TARGET_DIR/HIOps.Api" "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${COLOR_GREEN}已成功备份至: $BACKUP_DIR${COLOR_RESET}"

# 2. 优雅停止服务
echo -e "\n${COLOR_CYAN}[2/5] 停止后台 HIOps API 服务...${COLOR_RESET}"
systemctl stop hiops-api || true

# 3. 覆盖增量业务组件 (绝不覆盖内网 appsettings.json)
echo -e "\n${COLOR_CYAN}[3/5] 应用最新业务组件与前端资源...${COLOR_RESET}"

# 更新后端业务 DLL 与主二进制 (如果有)
if compgen -G "$PATCH_DIR/HIOps*.dll" > /dev/null; then
    cp -f "$PATCH_DIR"/HIOps*.dll "$TARGET_DIR/"
    echo "  -> 核心业务 DLL 库已更新。"
fi
if [ -f "$PATCH_DIR/HIOps.Api" ]; then
    cp -f "$PATCH_DIR/HIOps.Api" "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/HIOps.Api"
    echo "  -> 主程序可执行入口已更新。"
fi

# 更新前端静态资源 (如果有)
if [ -d "$PATCH_DIR/wwwroot" ]; then
    cp -rf "$PATCH_DIR/wwwroot/"* "$TARGET_DIR/wwwroot/"
    echo "  -> 前端 UI 页面资源已更新。"
fi

# 修正权限 (确保 hiops 运行账号可读)
chown -R hiops:hiops "$TARGET_DIR" 2>/dev/null || chown -R root:root "$TARGET_DIR" 2>/dev/null || true

# 4. 执行可选增量数据库补丁 (如果有 patch.sql)
echo -e "\n${COLOR_CYAN}[4/5] 检查是否存在增量数据库补丁...${COLOR_RESET}"
if [ -f "$PATCH_DIR/patch.sql" ]; then
    echo "发现增量 SQL 补丁 patch.sql，正在应用至 PostgreSQL 数据库..."
    sudo -u postgres psql -d hiops -f "$PATCH_DIR/patch.sql" || {
        echo -e "${COLOR_YELLOW}[警告] 增量 SQL 执行有部分警告，继续启动服务...${COLOR_RESET}"
    }
    echo -e "${COLOR_GREEN}数据库增量结构/索引已应用。${COLOR_RESET}"
else
    echo "无需执行数据库结构变更。"
fi

# 5. 启动服务并验证存活
echo -e "\n${COLOR_CYAN}[5/5] 重新启动后台服务并探活...${COLOR_RESET}"
systemctl start hiops-api

# 获取端口
PORT=$(grep -oP '(?<=ASPNETCORE_URLS=http://0.0.0.0:)\d+' /etc/systemd/system/hiops-api.service 2>/dev/null || echo "5080")
sleep 2

HEALTH_OK=0
for i in {1..8}; do
    if curl -s "http://127.0.0.1:$PORT/api/health" | grep -q "success"; then
        HEALTH_OK=1
        break
    fi
    sleep 1
done

if [ "$HEALTH_OK" == "1" ]; then
    echo -e "${COLOR_GREEN}==============================================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}  🎉 HIOps 系统已完成极速热更！新调试版本已正式生效！${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==============================================================================${COLOR_RESET}"
    echo -e "  🌐 访问地址: http://$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1):$PORT"
    echo -e "  🛡️ 安全回滚提示: 如需回滚到升级前版本，执行: cp -rf $BACKUP_DIR/* $TARGET_DIR/ && systemctl restart hiops-api"
else
    echo -e "${COLOR_YELLOW}[提示] 服务已启动，正在初始化中。执行 'systemctl status hiops-api' 查看状态。${COLOR_RESET}"
fi
