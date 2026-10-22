#!/usr/bin/env bash
# ==============================================================================
# HIOps 医院智能运维平台 — Linux 服务器 Agent 与采集桥一键配置脚本
# 适用系统: CentOS 7+ / RHEL 8,9 / openEuler / Kylin
# ==============================================================================

set -e

ZABBIX_SERVER_IP="192.168.114.29"
HIOPS_API_URL="http://192.168.114.30:5080"

echo "=== [1/3] 检测 Linux 发行版与环境 ==="
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
    echo "检测到系统: $OS_NAME $OS_VERSION"
else
    echo "未识别的 Linux 发行版"
    exit 1
fi

echo "=== [2/3] 配置 Zabbix Agent2 Active 模式 ==="
if command -v zabbix_agent2 &> /dev/null; then
    echo "Zabbix Agent2 已安装，更新主动注册配置..."
    CONF_FILE="/etc/zabbix/zabbix_agent2.conf"
    if [ -f "$CONF_FILE" ]; then
        sed -i "s/^ServerActive=.*/ServerActive=${ZABBIX_SERVER_IP}/" "$CONF_FILE"
        sed -i "s/^Hostname=.*/Hostname=$(hostname)/" "$CONF_FILE"
        systemctl restart zabbix-agent2
        echo "Zabbix Agent2 配置已更新并重启."
    fi
else
    echo "Zabbix Agent2 未安装，建议通过离线 rpm 包安装 (/root/zbx-rpms/)"
fi

echo "=== [3/3] 验证与 HIOps API (114.30) 联通性 ==="
if curl -s --connect-timeout 3 "$HIOPS_API_URL/health" &> /dev/null; then
    echo "✅ 成功连通 HIOps 平台中台 ($HIOPS_API_URL)"
else
    echo "⚠️ 警告: 无法连通 $HIOPS_API_URL，请检查 114.X 段安全组与端口配置"
fi

echo "=== Linux 端采集配置完成 ==="
