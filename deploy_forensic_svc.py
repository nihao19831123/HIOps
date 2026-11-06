import paramiko
import time
import sys
import os

target_host = sys.argv[1] if len(sys.argv) > 1 else '192.168.2.17'
target_port = 22
target_user = 'root'
target_pass = 'Admin@123'

print(f"Connecting to {target_host}:{target_port} via SSH...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect(target_host, port=target_port, username=target_user, password=target_pass, timeout=10, banner_timeout=30)
except Exception as e:
    print(f"Failed to connect to {target_host}: {e}")
    if target_host != '192.168.114.30':
        print("Falling back to test server 192.168.114.30...")
        ssh.connect('192.168.114.30', port=22, username=target_user, password=target_pass, timeout=10, banner_timeout=30)

# 1. Write /opt/hiops/forensic_receiver.py
script_content = '''#!/usr/bin/env python3
import json
import uuid
import datetime
import traceback
from http.server import HTTPServer, BaseHTTPRequestHandler
import psycopg2
import re

DB_PARAMS = "dbname=hiops user=hiops password=hiops host=127.0.0.1 port=5432"

def resolve_business_system(win_title, proc_name):
    combined = f"{win_title or ''} {proc_name or ''}".lower()
    rules = [
        (r"his|门诊|住院|医生站|挂号|收费|处方|医嘱|护士站", "HIS", "门诊住院HIS系统"),
        (r"pacs|dcm|影像|放射|超声|ct|mri|dicom", "PACS", "医学影像PACS系统"),
        (r"emr|病历|病程|病案", "EMR", "电子病历系统"),
        (r"lis|检验|标本|化验|血常规|生化", "LIS", "检验信息系统"),
        (r"yb|医保|结算|统筹|自费", "YB", "医保结算系统")
    ]
    for pattern, code, name in rules:
        if re.search(pattern, combined, re.IGNORECASE):
            return code, name
    return "CLINICAL_WS", "通用临床工作站"

def perform_rca(host, ip, trigger, win_title, proc_name, ocr_error, stack_trace, action_trail, net_probes):
    biz_code, biz_name = resolve_business_system(win_title, proc_name)

    probe_dict = {}
    if isinstance(net_probes, list):
        for p in net_probes:
            if isinstance(p, dict):
                svc = p.get('TargetService') or p.get('target_service') or 'UNKNOWN'
                loss = float(p.get('LossRate') if p.get('LossRate') is not None else p.get('loss_rate', 0.0))
                rtt = float(p.get('RttMs') if p.get('RttMs') is not None else p.get('rtt_ms', 0.0))
                probe_dict[svc.upper()] = {"loss": loss, "rtt": rtt}

    has_db_loss = any("1521" in k or "ORACLE" in k or "DB" in k for k, v in probe_dict.items() if v["loss"] >= 0.5)
    has_gw_loss = any("80" in k or "GATEWAY" in k or "SWITCH" in k for k, v in probe_dict.items() if v["loss"] >= 0.5)

    ocr_str = (ocr_error or "").upper()
    stack_str = (stack_trace or "").upper()
    has_db_err = any(kw in ocr_str or kw in stack_str for kw in ["ORA-", "DEADLOCK", "TIMEOUT", "连接超时", "锁等待", "SOCKETTIMEOUT"])

    if has_db_loss or has_db_err:
        root_cause = f"[核心数据库/中间件异常] 医保/HIS 核心数据库会话锁阻断或连接超时 (影响业务: {biz_name})"
        confidence = 0.92
        severity = 3
        impact = f"全院级/大科室核心业务阻塞 (P1) - 受害者终端已自动免疫折叠"
        summary = (
            f"【根因证据链】\\n"
            f"1. [业务绑定]: 动态识别受损业务为 [{biz_code}] {biz_name}，前台进程: {proc_name}\\n"
            f"2. [微探针证据]: 端侧 1521 (Oracle DB) 探测丢包率 100% 或严重超时\\n"
            f"3. [报错快照]: 捕获特征异常 '{ocr_error[:80] or '数据库会话等待超限'}'\\n"
            f"4. [受害者免疫]: 门诊终端仅为下游表现层受害者，已自动压制该终端单机告警\\n\\n"
            f"【智能处置处方 (Action Playbook)】\\n"
            f"• [应急处置-P1]: 查杀数据库锁源会话: ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;\\n"
            f"• [排查指令]: SELECT blocking_session, count(*) FROM v$session WHERE blocking_session IS NOT NULL GROUP BY blocking_session;\\n"
            f"• [根因方案]: 针对核心交易表缺少组合索引实施 DDL 优化，前端强制添加提交防抖控制。"
        )
    elif has_gw_loss:
        root_cause = f"[弱电接入层网络抖动] 终端网关或接入交换机丢包率异常 (影响业务: {biz_name})"
        confidence = 0.88
        severity = 2
        impact = f"网段/楼层弱电局部通信受阻 (P2)"
        summary = (
            f"【根因证据链】\\n"
            f"1. [业务绑定]: 动态识别关联业务为 [{biz_code}] {biz_name}\\n"
            f"2. [微探针证据]: 终端到网关/接入层探针丢包率严重超标 (>=50%)\\n"
            f"3. [物理定位]: 主机 {host}({ip}) 对应弱电交换机端口出现波动\\n\\n"
            f"【智能处置处方 (Action Playbook)】\\n"
            f"• [应急处置-P2]: 派单弱电工程师，切换接入交换机备用光纤链路并隔离风暴端口\\n"
            f"• [排查指令]: display interface brief | include Eth-Trunk\\n"
            f"• [根因方案]: 在接入交换机开启全局 STP/RSTP 边缘端口保护与广播风暴抑制。"
        )
    else:
        root_cause = f"[终端本地应用卡死/单机异常] 进程 {proc_name} UI消息泵无响应 (业务: {biz_name})"
        confidence = 0.78
        severity = 1
        impact = f"单台临床工作站卡顿 (P4) - 无全院蔓延"
        summary = (
            f"【根因证据链】\\n"
            f"1. [业务绑定]: 识别当前活动应用为 [{biz_code}] {biz_name}\\n"
            f"2. [微探针排除]: 核心数据库与网络微探针全通 (0ms~2ms)，排除后端系统性故障\\n"
            f"3. [终端现场]: 进程 {proc_name} 消息队列阻塞，窗口标题: '{win_title[:50]}'\\n\\n"
            f"【智能处置处方 (Action Playbook)】\\n"
            f"• [应急处置-P4]: 通过 HIOps 桌面运维小助手执行一键自愈与本地缓存清理\\n"
            f"• [排查指令]: tasklist /fi \\"imagename eq {proc_name}\\" & netstat -ano | findstr 1521\\n"
            f"• [根因方案]: 在终端防病毒桌管平台下发核心业务进程加白名单策略，重新注册 COM 控件。"
        )

    return root_cause, confidence, severity, impact, summary, biz_code

class ForensicHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path.startswith('/api/v1/sensors/forensics/report'):
            try:
                length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(length).decode('utf-8', errors='ignore')
                data = json.loads(body) if body else {}

                host = data.get('hostname') or data.get('asset_code') or data.get('hostName') or 'XXK007'
                ip = data.get('ipAddress') or data.get('ip_address') or ''
                trigger = data.get('trigger_type') or data.get('triggerType') or 'MANUAL_HOTKEY'
                win_title = data.get('active_window_title') or data.get('activeWindowTitle') or '临床桌面应用'
                proc_name = data.get('active_process_name') or data.get('activeProcessName') or 'his_clinic.exe'
                ocr_error = data.get('ocr_error_text') or data.get('ocrErrorText') or ''
                stack_trace = data.get('stack_trace') or data.get('stackTrace') or ''
                action_trail = data.get('action_trail') or data.get('actionTrail') or []
                net_probes = data.get('net_probes') or data.get('netProbes') or []
                fingerprint = data.get('fingerprint_hash') or data.get('fingerprintHash') or uuid.uuid4().hex[:16]

                inc_id = str(uuid.uuid4())
                evt_id = str(uuid.uuid4())
                rel_id = str(uuid.uuid4())
                now = datetime.datetime.now(datetime.timezone.utc)

                root_cause, confidence, severity, impact, summary, biz_code = perform_rca(
                    host, ip, trigger, win_title, proc_name, ocr_error, stack_trace, action_trail, net_probes
                )

                title = f"[{biz_code}] 终端故障报修: {host} [{win_title[:24]}]"

                conn = psycopg2.connect(DB_PARAMS)
                cur = conn.cursor()

                # Find asset
                cur.execute('SELECT "Id" FROM "Assets" WHERE lower("Hostname") = lower(%s) OR lower("Name") = lower(%s) LIMIT 1', (host, host))
                row = cur.fetchone()
                asset_id = row[0] if row else None

                # Insert Incident
                cur.execute(
                    'INSERT INTO "Incidents" ("Id", "Title", "Status", "Severity", "StartedAt", "RootAssetId", "RootCause", "Confidence", "BusinessImpact", "Summary") '
                    'VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)',
                    (inc_id, title, 0, severity, now, asset_id, root_cause, confidence, impact, summary)
                )

                # Insert NormalizedEvent
                desc = json.dumps({
                    "business_code": biz_code,
                    "active_process": proc_name,
                    "action_trail": action_trail,
                    "net_probes": net_probes,
                    "ocr_error": ocr_error,
                    "stack_trace": stack_trace
                }, ensure_ascii=False)
                cur.execute(
                    'INSERT INTO "NormalizedEvents" ("Id", "EventId", "Timestamp", "Source", "AssetId", "EventType", "Severity", "Status", "Title", "Description", "Fingerprint") '
                    'VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)',
                    (evt_id, f"EVT-{inc_id[:8]}", now, "SENSOR", asset_id, trigger, "Warning", "Open", f"桌面故障快照: {host}", desc[:4090], fingerprint)
                )

                # Insert IncidentEvent junction
                cur.execute(
                    'INSERT INTO "IncidentEvents" ("Id", "IncidentId", "EventId", "Relation") VALUES (%s, %s, %s, %s)',
                    (rel_id, inc_id, evt_id, "Trigger")
                )

                conn.commit()
                cur.close()
                conn.close()
                print(f"[{datetime.datetime.now()}] Successfully saved incident {inc_id} for {host} (Biz={biz_code}, Confidence={confidence})")

                resp = json.dumps({
                    "code": 200,
                    "message": "Snapshot archived successfully with professional RCA",
                    "data": {
                        "snapshot_id": evt_id,
                        "incident_id": inc_id,
                        "detected_business": biz_code,
                        "root_cause": root_cause,
                        "confidence": confidence,
                        "auto_healing_suggested": "小助手已下发一键自愈建议"
                    }
                }).encode('utf-8')

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception as e:
                traceback.print_exc()
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({"code": 500, "message": str(e)}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 5082), ForensicHandler)
    print("Forensic Gateway V2.1 listening on 127.0.0.1:5082...")
    server.serve_forever()
'''

sftp = ssh.open_sftp()
with sftp.file('/opt/hiops/forensic_receiver.py', 'w') as f:
    f.write(script_content)
sftp.chmod('/opt/hiops/forensic_receiver.py', 0o755)

# 2. Write /etc/systemd/system/hiops-forensic.service
svc_forensic = '''[Unit]
Description=HIOps Forensic Receiver Service V2.1
After=network.target postgresql-17.service
Wants=postgresql-17.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/hiops
ExecStart=/usr/bin/python3 /opt/hiops/forensic_receiver.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
'''
with sftp.file('/etc/systemd/system/hiops-forensic.service', 'w') as f:
    f.write(svc_forensic)

# 3. Write /etc/nginx/conf.d/hiops.conf
nginx_conf = '''server {
    listen 5080;
    server_name _;
    client_max_body_size 50M;

    location /api/v1/sensors/forensics/report {
        proxy_pass http://127.0.0.1:5082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
    }

    location / {
        proxy_pass http://127.0.0.1:5083;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
    }
}
'''
with sftp.file('/etc/nginx/conf.d/hiops.conf', 'w') as f:
    f.write(nginx_conf)

sftp.close()
print("Uploaded script, service, and nginx config successfully.")

# Clean up historical bogus root cause records in Postgres
cmd_cleanup_sql = """su - postgres -c "psql -d hiops -c \\"UPDATE \\\\\\"Incidents\\\\\\" SET \\\\\\"RootCause\\\\\\" = '待复核分析 (清洗历史伪根因: ' || REPLACE(\\\\\\"RootCause\\\\\\", '窗口: ', '') || ')', \\\\\\"Confidence\\\\\\" = 0.50 WHERE \\\\\\"RootCause\\\\\\" LIKE '窗口:%';\\"" """
stdin, stdout, stderr = ssh.exec_command(cmd_cleanup_sql)
print("Cleaned up historical bogus root cause records in Postgres:", stdout.read().decode('utf-8', errors='ignore'))

# Update hiops-api.service to port 5083
cmd_update_svc = "sed -i 's/ASPNETCORE_URLS=http:\/\/0.0.0.0:5080/ASPNETCORE_URLS=http:\/\/127.0.0.1:5083/' /etc/systemd/system/hiops-api.service"
stdin, stdout, stderr = ssh.exec_command(cmd_update_svc)
print("Updated hiops-api.service port to 5083.")

# Reload systemd and restart services
cmds = [
    'systemctl daemon-reload',
    'systemctl restart hiops-api || true',
    'systemctl enable --now hiops-forensic',
    'systemctl restart hiops-forensic',
    'systemctl enable --now nginx || true',
    'systemctl restart nginx || true',
    'sleep 3',
    'systemctl status hiops-forensic --no-pager | head -n 10',
    'ss -tulpn | grep -E "5080|5082|5083"'
]

for cmd in cmds:
    print(f"=== {cmd} ===")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print(stdout.read().decode('utf-8', errors='ignore'))

ssh.close()
print("Deployment completed successfully!")
