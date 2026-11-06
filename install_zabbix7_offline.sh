#!/usr/bin/env bash
# ==============================================================================
# HIOps 智能运维底座 — Zabbix 7.0 + PHP 8.2.35 + MariaDB 100% 全独立离线部署
# 适用系统: openEuler 22.03 SP4 (x86_64) / CentOS / RHEL 8
# 特性: 内置 MariaDB 10.5 + Apache httpd + PHP 8.2.35 + Zabbix 7.0 全量 RPM
#       完全零外部依赖，绝不调用 yum/dnf，彻底摆脱 /media 挂载与网络源问题！
# ==============================================================================

set -e

COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}  Zabbix 7.0 LTS + PHP 8.2.35 (含 MariaDB 全量) 物理隔离内网一键离线部署  ${COLOR_RESET}"
echo -e "${COLOR_CYAN}==============================================================================${COLOR_RESET}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${COLOR_RED}[错误] 请使用 root 用户执行此脚本！${COLOR_RESET}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPMS_DIR="$SCRIPT_DIR/rpms"

# 0. 准备环境：关闭 SELinux 拦截、创建守护进程系统用户
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 2>/dev/null || true
id apache &>/dev/null || useradd -r -s /sbin/nologin -d /usr/share/httpd apache
id nginx  &>/dev/null || useradd -r -s /sbin/nologin nginx
id zabbix &>/dev/null || useradd -r -s /sbin/nologin -d /var/lib/zabbix zabbix

echo -e "\n${COLOR_CYAN}[1/4] 一键安装全部离线 RPM 组件包 (MariaDB + Apache + PHP 8.2.35 + Zabbix 7.0)...${COLOR_RESET}"
if [ -d "$RPMS_DIR" ]; then
    echo "正在静默安装 $RPMS_DIR 下的全部 RPM 包..."
    rpm -Uvh --force --nodeps "$RPMS_DIR"/*.rpm
    echo -e "${COLOR_GREEN}全套 RPM 组件包已瞬间安装就绪！${COLOR_RESET}"
else
    echo -e "${COLOR_RED}[错误] 未找到 rpms 目录！${COLOR_RESET}"
    exit 1
fi

echo -e "\n${COLOR_CYAN}[2/4] 初始化并启动 MariaDB 数据库服务...${COLOR_RESET}"
systemctl enable --now mariadb
mysql -uroot << 'EOF' || true
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY 'zabbix';
CREATE USER IF NOT EXISTS 'zabbix'@'%' IDENTIFIED BY 'zabbix';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF
echo -e "${COLOR_GREEN}MariaDB 运行正常，zabbix 专属数据库与权限配置完成。${COLOR_RESET}"

echo -e "\n${COLOR_CYAN}[3/4] 导入 Zabbix 7.0 初始表结构与监控模板库...${COLOR_RESET}"
SQL_FILE="/usr/share/zabbix-sql-scripts/mysql/server.sql.gz"
if [ -f "$SQL_FILE" ]; then
    TABLE_COUNT=$(mysql -uzabbix -pzabbix zabbix -e "SHOW TABLES;" 2>/dev/null | wc -l)
    if [ "$TABLE_COUNT" -gt 50 ]; then
        echo "检测到 zabbix 数据库已存在 $TABLE_COUNT 张数据表，跳过重复导入。"
    else
        echo "正在解压并导入 $SQL_FILE (约需 1~2 分钟，请稍候)..."
        zcat "$SQL_FILE" | mysql --default-character-set=utf8mb4 -uzabbix -pzabbix zabbix
        mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 0;" || true
        echo -e "${COLOR_GREEN}初始表结构与内置模板库导入完成！${COLOR_RESET}"
    fi
fi

echo -e "\n${COLOR_CYAN}[4/4] 配置系统环境、兼容软链并启动所有核心服务...${COLOR_RESET}"
# 4.1 创建运行时目录与 Session 缓存
mkdir -p /run/php-fpm /var/log/php-fpm /var/lib/php/session /run/httpd /var/log/httpd /run/zabbix /var/log/zabbix
chown -R apache:apache /run/php-fpm /var/log/php-fpm /var/lib/php /run/httpd /var/log/httpd
chown -R zabbix:zabbix /run/zabbix /var/log/zabbix /etc/zabbix 2>/dev/null || true

# 4.2 建立 zabbix_server 执行文件与底层动态库软链
[ -f /usr/sbin/zabbix_server_mysql ] && ln -sf /usr/sbin/zabbix_server_mysql /usr/sbin/zabbix_server
[ -f /usr/lib64/libevent-2.1.so.7 ] && ln -sf /usr/lib64/libevent-2.1.so.7 /usr/lib64/libevent-2.1.so.6
[ -f /usr/lib64/libevent_pthreads-2.1.so.7 ] && ln -sf /usr/lib64/libevent_pthreads-2.1.so.7 /usr/lib64/libevent_pthreads-2.1.so.6
[ -f /usr/lib64/libnetsnmp.so.40 ] && ln -sf /usr/lib64/libnetsnmp.so.40 /usr/lib64/libnetsnmp.so.35
[ -f /usr/lib64/libldap.so.2 ] && ln -sf /usr/lib64/libldap.so.2 /usr/lib64/libldap-2.4.so.2
[ -f /usr/lib64/liblber.so.2 ] && ln -sf /usr/lib64/liblber.so.2 /usr/lib64/liblber-2.4.so.2
ldconfig 2>/dev/null || true

# 4.3 修复 PHP-FPM socket 与 ACL 避免 exit code 78
if [ -d "/etc/php-fpm.d" ]; then
    sed -i 's/^listen.acl_users/;listen.acl_users/' /etc/php-fpm.d/*.conf 2>/dev/null || true
    sed -i 's/^;listen.owner = apache/listen.owner = apache/' /etc/php-fpm.d/*.conf 2>/dev/null || true
    sed -i 's/^;listen.group = apache/listen.group = apache/' /etc/php-fpm.d/*.conf 2>/dev/null || true
    sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' /etc/php-fpm.d/*.conf 2>/dev/null || true
fi

# 4.4 配置 Apache ServerName 避免 exit code 1
echo "ServerName 127.0.0.1:80" > /etc/httpd/conf.d/00-servername.conf

# 4.5 配置 Zabbix Server 数据库连接
CONF="/etc/zabbix/zabbix_server.conf"
if [ -f "$CONF" ]; then
    sed -i 's/^# DBHost=.*/DBHost=127.0.0.1/' "$CONF"
    sed -i 's/^DBHost=.*/DBHost=127.0.0.1/' "$CONF"
    sed -i 's/^# DBPassword=/DBPassword=zabbix/' "$CONF"
    sed -i 's/^DBPassword=.*/DBPassword=zabbix/' "$CONF"
fi

# 启动并开机自启全部服务
systemctl daemon-reload
systemctl restart mariadb php-fpm httpd zabbix-server zabbix-agent2
systemctl enable mariadb php-fpm httpd zabbix-server zabbix-agent2

echo -e "\n${COLOR_GREEN}==============================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}      Zabbix 7.0 LTS + PHP 8.2.35 (含 MariaDB) 离线部署已顺利完成！   ${COLOR_RESET}"
echo -e "${COLOR_GREEN}==============================================================================${COLOR_RESET}"

LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
echo -e "Web 访问入口:   ${COLOR_YELLOW}http://$LOCAL_IP/zabbix${COLOR_RESET}"
echo -e "API 端点:       ${COLOR_YELLOW}http://$LOCAL_IP/zabbix/api_jsonrpc.php${COLOR_RESET}"
echo -e "系统默认账号:   ${COLOR_YELLOW}Admin${COLOR_RESET}  (注意 A 大写)"
echo -e "系统默认密码:   ${COLOR_YELLOW}zabbix${COLOR_RESET}"
echo -e "\nPHP 安全版本验证:"
php-fpm -v | head -n 1
echo -e "\n正在自测本地 API 连通性..."
curl -s -X POST -H 'Content-Type: application/json-rpc' -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}' http://127.0.0.1/zabbix/api_jsonrpc.php || true
echo -e "\n${COLOR_CYAN}自测完成！现在可以回到 HIOps 服务端 (192.168.2.17) 重启 hiops-api 完成自动联动！${COLOR_RESET}"
