import paramiko
import time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=10, banner_timeout=30)

# 1. Write /opt/hiops/forensic_receiver.py
script_content = '''#!/usr/bin/env python3
import json
import uuid
import datetime
import traceback
from http.server import HTTPServer, BaseHTTPRequestHandler
import psycopg2

DB_PARAMS = "dbname=hiops user=hiops password=hiops host=127.0.0.1 port=5432"

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
                ocr_error = data.get('ocr_error_text') or data.get('ocrErrorText') or ''
                stack_trace = data.get('stack_trace') or data.get('stackTrace') or ''
                action_trail = data.get('action_trail') or data.get('actionTrail') or []
                net_probes = data.get('net_probes') or data.get('netProbes') or []
                fingerprint = data.get('fingerprint_hash') or data.get('fingerprintHash') or uuid.uuid4().hex[:16]

                inc_id = str(uuid.uuid4())
                evt_id = str(uuid.uuid4())
                rel_id = str(uuid.uuid4())
                now = datetime.datetime.now(datetime.timezone.utc)

                title = f"终端一键报障: {host} [{win_title[:30]}]"
                root_cause = f"窗口: {win_title[:100]}"
                if ocr_error:
                    root_cause += f" | 报错: {ocr_error[:100]}"

                summary = f"终端 {host}({ip}) 发起一键报障; 触发: {trigger}; 窗口: {win_title[:50]}; 时序步骤: {len(action_trail)}条"

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
                    (inc_id, title, 0, 2, now, asset_id, root_cause, 0.95, "门诊临床终端异常 (一键报障)", summary)
                )

                # Insert NormalizedEvent
                desc = json.dumps({
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
                print(f"[{datetime.datetime.now()}] Successfully saved incident {inc_id} for {host}")

                resp = json.dumps({
                    "code": 200,
                    "message": "Snapshot archived successfully",
                    "data": {
                        "snapshot_id": evt_id,
                        "incident_id": inc_id,
                        "auto_healing_suggested": None
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
    print("Forensic Gateway listening on 127.0.0.1:5082...")
    server.serve_forever()
'''

sftp = ssh.open_sftp()
with sftp.file('/opt/hiops/forensic_receiver.py', 'w') as f:
    f.write(script_content)
sftp.chmod('/opt/hiops/forensic_receiver.py', 0o755)

# 2. Write /etc/systemd/system/hiops-forensic.service
svc_forensic = '''[Unit]
Description=HIOps Forensic Receiver Service
After=network.target postgresql-17.service

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

# Update hiops-api.service to port 5083
cmd_update_svc = "sed -i 's/ASPNETCORE_URLS=http:\/\/0.0.0.0:5080/ASPNETCORE_URLS=http:\/\/127.0.0.1:5083/' /etc/systemd/system/hiops-api.service"
stdin, stdout, stderr = ssh.exec_command(cmd_update_svc)
print("Updated hiops-api.service port to 5083.")

# Reload systemd and restart services
cmds = [
    'systemctl daemon-reload',
    'systemctl restart hiops-api',
    'systemctl enable --now hiops-forensic',
    'systemctl restart hiops-forensic',
    'systemctl enable --now nginx',
    'systemctl restart nginx',
    'sleep 3',
    'systemctl status hiops-api --no-pager | head -n 10',
    'systemctl status hiops-forensic --no-pager | head -n 10',
    'systemctl status nginx --no-pager | head -n 10',
    'ss -tulpn | grep -E "5080|5082|5083"'
]

for cmd in cmds:
    print(f"=== {cmd} ===")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print(stdout.read().decode('utf-8', errors='ignore'))

ssh.close()
