import paramiko
import time

def get_ssh():
    for attempt in range(5):
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=10, banner_timeout=30)
            return ssh
        except Exception as e:
            time.sleep(2)
    raise RuntimeError("Failed to connect to SSH")

ssh = get_ssh()
commands = [
    'cat /opt/hiops/api/appsettings.json',
    'python3 -c "import psycopg2; print(\"psycopg2 is installed\")" 2>&1',
    'which nginx 2>&1',
    'which psql 2>&1'
]

for cmd in commands:
    print(f"=== {cmd} ===")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print(stdout.read().decode('utf-8', errors='ignore'))
ssh.close()
