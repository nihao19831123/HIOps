import os
import glob
import paramiko

print("=== Checking local Documents ===")
doc_path = r"C:\Users\wufeng\Documents"
for f in os.listdir(doc_path):
    if any(k in f for k in ["验收", "设计", "HIOps", "hiops", "方案"]):
        print("  Local:", f)

print("\n=== Checking 192.168.2.17 ===")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect('192.168.2.17', port=22, username='root', password='Admin@123', timeout=5)
    cmds = [
        "ls -la /opt/hiops",
        "ls -la /root",
        "find /root /opt /home -name '*.md' -o -name '*验收*' -o -name '*设计*' 2>/dev/null"
    ]
    for c in cmds:
        print("CMD:", c)
        stdin, stdout, stderr = ssh.exec_command(c)
        print(stdout.read().decode('utf-8', errors='ignore'))
    ssh.close()
except Exception as e:
    print("Error on 192.168.2.17:", e)
