#!/usr/bin/env bash
# ==============================================================================
# HIOps 医院智能运维平台 — openEuler 22.03 离线安装与配置 PostgreSQL 辅助脚本
# ==============================================================================

set -e

COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}          openEuler 22.03 LTS — PostgreSQL 自动化配置向导                     ${COLOR_RESET}"
echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"

# 1. 检测是否已安装 psql
if command -v psql &>/dev/null; then
    echo -e "${COLOR_GREEN}[检测] 系统已安装 PostgreSQL ($(psql --version))${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}[1/4] 正在安装 PostgreSQL 服务端...${COLOR_RESET}"
    if [ -d "$SCRIPT_DIR/packages/pgsql" ] && compgen -G "$SCRIPT_DIR/packages/pgsql/*.rpm" > /dev/null; then
        echo -e "${COLOR_GREEN}检测到离线 RPM 安装包目录 ($SCRIPT_DIR/packages/pgsql)，正在执行纯离线安装...${COLOR_RESET}"
        rpm -Uvh --nodeps "$SCRIPT_DIR/packages/pgsql/"*.rpm
    elif dnf install -y postgresql-server postgresql-contrib 2>/dev/null; then
        echo -e "${COLOR_GREEN}PostgreSQL 软件包通过 dnf 安装成功！${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}[失败] 安装失败！未找到离线 packages/pgsql 包，且 dnf 未配置内网源或挂载 ISO 镜像。${COLOR_RESET}"
        exit 1
    fi
fi

# 2. 初始化数据库集群 (若尚未初始化)
PG_DATA="/var/lib/pgsql/data"
if [ ! -f "$PG_DATA/PG_VERSION" ]; then
    echo -e "${COLOR_YELLOW}[2/4] 正在初始化数据库存储目录 ($PG_DATA)...${COLOR_RESET}"
    if command -v postgresql-setup &>/dev/null; then
        postgresql-setup --initdb
    else
        su - postgres -c "initdb -D $PG_DATA"
    fi
    echo -e "${COLOR_GREEN}数据库初始化完成。${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}[跳过] 数据库目录已存在 ($PG_DATA)。${COLOR_RESET}"
fi

# 3. 配置本地密码认证 (pg_hba.conf) 防止 ident 认证拦截
echo -e "${COLOR_YELLOW}[3/4] 配置安全认证 (允许本地密码认证)...${COLOR_RESET}"
HBA_CONF="$PG_DATA/pg_hba.conf"
if [ -f "$HBA_CONF" ]; then
    sed -i '/127.0.0.1\/32/s/ident/md5/' "$HBA_CONF" 2>/dev/null || true
    sed -i '/::1\/128/s/ident/md5/' "$HBA_CONF" 2>/dev/null || true
    echo -e "${COLOR_GREEN}pg_hba.conf 本地认证规则已调整为 md5。${COLOR_RESET}"
fi

# 4. 启动服务并设置开机自启
echo -e "${COLOR_YELLOW}[4/4] 启动 PostgreSQL 服务并设置开机自启...${COLOR_RESET}"
systemctl daemon-reload
systemctl enable --now postgresql

# 5. 快速测试可用性
echo -e "\n${COLOR_CYAN}PostgreSQL 运行状态验证:${COLOR_RESET}"
systemctl is-active postgresql

echo -e "\n${COLOR_GREEN}==============================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN} [完成] openEuler 22.03 PostgreSQL 数据库已成功就绪！${COLOR_RESET}"
echo -e "${COLOR_GREEN} 接下来您只需直接执行: bash init_hiops_offline.sh 即可自动建库并恢复数据！${COLOR_RESET}"
echo -e "${COLOR_GREEN}==============================================================================${COLOR_RESET}"
