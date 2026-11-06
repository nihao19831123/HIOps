#!/usr/bin/env bash
# ==============================================================================
# HIOps 医院智能信息运维平台 — 物理隔离内网离线一键初始化部署脚本
# 适用环境: 纯物理隔离内网（无外网、无在线模型、无外网依赖）
# 适用系统: CentOS 7/8/9, RHEL 8/9, 银河麒麟(Kylin V10), 统信(UOS), openEuler, Ubuntu
# ==============================================================================

set -e

COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}       HIOps 医院智能运维平台 — 物理隔离内网服务端一键离线部署程序       ${COLOR_RESET}"
echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${COLOR_RED}[错误] 请使用 root 用户或 sudo 执行此脚本！${COLOR_RESET}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HIOPS_INSTALL_DIR="/opt/hiops/api"
DB_NAME="hiops"
DB_USER="hiops"
DB_PASS="hiops"

# 获取内网本机主 IP
LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)

echo -e "\n${COLOR_YELLOW}>>> 请输入内网配置参数（直接回车使用默认值）: ${COLOR_RESET}"
read -rp "1. HIOps 服务监听端口 [默认 5080]: " INPUT_PORT
HIOPS_PORT="${INPUT_PORT:-5080}"

read -rp "2. 内网 Zabbix API 地址 [默认 http://192.168.2.18/zabbix/api_jsonrpc.php]: " INPUT_ZBX
ZABBIX_URL="${INPUT_ZBX:-http://192.168.2.18/zabbix/api_jsonrpc.php}"

read -rp "3. 内网 Zabbix 用户名 [默认 Admin]: " INPUT_ZBX_USER
ZABBIX_USER="${INPUT_ZBX_USER:-Admin}"

read -rp "4. 内网 Zabbix 密码 [默认 zabbix]: " INPUT_ZBX_PASS
ZABBIX_PASS="${INPUT_ZBX_PASS:-zabbix}"

echo -e "\n${COLOR_GREEN}配置确认:${COLOR_RESET}"
echo "  - 本机 IP 地址: $LOCAL_IP"
echo "  - Web/API 端口: $HIOPS_PORT"
echo "  - Zabbix 端点: $ZABBIX_URL"
echo "  - 目标安装路径: $HIOPS_INSTALL_DIR"

# 2. 检查或安装 PostgreSQL
echo -e "\n${COLOR_CYAN}[1/5] 检查与初始化 PostgreSQL 数据库服务...${COLOR_RESET}"
if ! command -v psql &> /dev/null; then
    echo -e "${COLOR_YELLOW}未检测到 PostgreSQL，尝试从当前离线 packages 目录安装...${COLOR_RESET}"
    if [ -d "$SCRIPT_DIR/packages/pgsql" ]; then
        if command -v dnf &> /dev/null || command -v yum &> /dev/null; then
            rpm -Uvh --nodeps "$SCRIPT_DIR/packages/pgsql/"*.rpm || true
        elif command -v dpkg &> /dev/null; then
            dpkg -i "$SCRIPT_DIR/packages/pgsql/"*.deb || true
        fi
    else
        echo -e "${COLOR_RED}[错误] 未安装 PostgreSQL 且未找到离线安装包目录 ($SCRIPT_DIR/packages/pgsql)！${COLOR_RESET}"
        echo "请提前在内网服务器安装好 PostgreSQL 15/16/17。"
        exit 1
    fi
fi

# 确保 postgresql 服务已启动
for svc in postgresql postgresql-17 postgresql-16 postgresql-15; do
    if systemctl list-unit-files | grep -q "^$svc"; then
        PG_SVC=$svc
        break
    fi
done

if [ -n "$PG_SVC" ]; then
    systemctl enable --now "$PG_SVC" || true
    echo -e "${COLOR_GREEN}PostgreSQL 服务 ($PG_SVC) 运行正常。${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}未能自动识别 postgresql service 名，假设已在后台运行。${COLOR_RESET}"
fi

# 3. 初始化数据库与用户
echo -e "\n${COLOR_CYAN}[2/5] 创建 hiops 专用数据库与权限...${COLOR_RESET}"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>/dev/null || true

# 导入基础表结构与种子数据
if [ -f "$SCRIPT_DIR/hiops.sql" ]; then
    echo "正在从 $SCRIPT_DIR/hiops.sql 恢复全量数据库 (跨版本通用 SQL)..."
    cp "$SCRIPT_DIR/hiops.sql" /tmp/hiops.sql
    chmod 644 /tmp/hiops.sql
    sudo -u postgres psql -d "$DB_NAME" -f /tmp/hiops.sql > /dev/null 2>&1 || true
    rm -f /tmp/hiops.sql
elif [ -f "$SCRIPT_DIR/db/hiops_offline_dump.sql" ]; then
    echo "正在从 $SCRIPT_DIR/db/hiops_offline_dump.sql 恢复基础表结构..."
    sudo -u postgres psql -d "$DB_NAME" -f "$SCRIPT_DIR/db/hiops_offline_dump.sql" > /dev/null
elif [ -f "$SCRIPT_DIR/hiops.dump" ]; then
    echo "正在从 $SCRIPT_DIR/hiops.dump 恢复数据库..."
    cp "$SCRIPT_DIR/hiops.dump" /tmp/hiops.dump
    chmod 644 /tmp/hiops.dump
    sudo -u postgres pg_restore -d "$DB_NAME" --clean --if-exists /tmp/hiops.dump 2>/dev/null || true
    rm -f /tmp/hiops.dump
else
    echo "未找到 dump 文件，依次执行 schema 与 seed 脚本..."
    for f in "$SCRIPT_DIR/db/01_init_schema.sql" "$SCRIPT_DIR/db/02_partition_maintenance.sql" "$SCRIPT_DIR/db/03_seed_data.sql"; do
        if [ -f "$f" ]; then
            echo "执行 $f ..."
            sudo -u postgres psql -d "$DB_NAME" -f "$f" > /dev/null
        fi
    done
fi

# 确保高性能覆盖索引存在（防止 200 万心跳下大查询超时）
echo "确保探针看护高性能联合索引建立..."
sudo -u postgres psql -d "$DB_NAME" -c 'CREATE INDEX IF NOT EXISTS idx_ah_sensor_host_ip_reported ON "AgentHeartbeats" ("AgentId", "Hostname", "IpAddress", "ReportedAt" DESC);' 2>/dev/null || true

# 4. 部署 HIOps 自包含二进制包
echo -e "\n${COLOR_CYAN}[3/5] 部署 HIOps 平台二进制文件与前端资产...${COLOR_RESET}"
mkdir -p "$HIOPS_INSTALL_DIR"
if [ -d "$SCRIPT_DIR/api" ]; then
    cp -r "$SCRIPT_DIR/api/"* "$HIOPS_INSTALL_DIR/"
else
    echo -e "${COLOR_RED}[错误] 未在当前目录下找到 api/ 程序包！${COLOR_RESET}"
    exit 1
fi

chmod +x "$HIOPS_INSTALL_DIR/HIOps.Api" 2>/dev/null || true

# 5. 更新 appsettings.json 适配内网环境
echo -e "\n${COLOR_CYAN}[4/5] 写入内网服务配置 (appsettings.json)...${COLOR_RESET}"
APP_SETTINGS="$HIOPS_INSTALL_DIR/appsettings.json"
if [ -f "$APP_SETTINGS" ]; then
    # 使用 python/sed 安全更新 Zabbix 地址与账号
    python3 -c "
import json
with open('$APP_SETTINGS', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

cfg.setdefault('ConnectionStrings', {})['PostgreSQL'] = 'Host=127.0.0.1;Port=5432;Database=$DB_NAME;Username=$DB_USER;Password=$DB_PASS'
cfg.setdefault('Zabbix', {})['BaseUrl'] = '$ZABBIX_URL'
cfg['Zabbix']['User'] = '$ZABBIX_USER'
cfg['Zabbix']['Password'] = '$ZABBIX_PASS'
cfg['Zabbix']['Enabled'] = True

# 保持离线模式，禁用外网云模型
cfg.setdefault('SemanticAdjudication', {})['Mode'] = 'Disabled'

with open('$APP_SETTINGS', 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
" 2>/dev/null || true
    echo -e "${COLOR_GREEN}配置文件已写入内网环境参数。${COLOR_RESET}"
fi

# 6. 配置 systemd 服务并自启
echo -e "\n${COLOR_CYAN}[5/5] 注册并启动 Linux systemd 服务 (hiops-api)...${COLOR_RESET}"
cat << EOF > /etc/systemd/system/hiops-api.service
[Unit]
Description=HIOps Hospital Intelligent Operations Platform
After=network.target ${PG_SVC:-postgresql.service}

[Service]
Type=simple
User=root
WorkingDirectory=$HIOPS_INSTALL_DIR
ExecStart=$HIOPS_INSTALL_DIR/HIOps.Api --urls "http://0.0.0.0:$HIOPS_PORT"
Restart=always
RestartSec=5
StandardOutput=append:/var/log/hiops/api.log
StandardError=append:/var/log/hiops/api.log
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /var/log/hiops
systemctl daemon-reload
systemctl enable hiops-api
systemctl restart hiops-api

# 开放系统防火墙端口
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --add-port=${HIOPS_PORT}/tcp --permanent >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
fi

# 7. 部署健康检查
sleep 3
echo -e "\n${COLOR_CYAN}=== 正在验证服务存活状态 ===${COLOR_RESET}"
for i in {1..10}; do
    if curl -s "http://127.0.0.1:$HIOPS_PORT/api/health" | grep -q "success"; then
        HEALTH_OK=1
        break
    fi
    sleep 1
done

if [ "$HEALTH_OK" == "1" ]; then
    echo -e "${COLOR_GREEN}==============================================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}  🎉 HIOps 系统在内网环境已成功初始化并顺利启动！${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==============================================================================${COLOR_RESET}"
    echo -e "  🌐 内网访问地址:   ${COLOR_YELLOW}http://$LOCAL_IP:$HIOPS_PORT${COLOR_RESET}"
    echo -e "  👤 默认管理员账号: ${COLOR_YELLOW}admin${COLOR_RESET}"
    echo -e "  🔑 默认管理员密码: ${COLOR_YELLOW}Admin@123${COLOR_RESET}"
    echo -e "  📡 探针上报基地址: ${COLOR_YELLOW}http://$LOCAL_IP:$HIOPS_PORT${COLOR_RESET}"
    echo -e "  📋 服务运维命令:   systemctl status hiops-api / systemctl restart hiops-api"
    echo -e "  📜 运行日志查看:   tail -f /var/log/hiops/api.log"
    echo -e "${COLOR_GREEN}==============================================================================${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}[提示] 服务正在拉起中，请稍后执行 'systemctl status hiops-api' 查看状态。${COLOR_RESET}"
fi
