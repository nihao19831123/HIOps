import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123')

cmds = [
    'ls -la /opt/hiops',
    'ls -la /root',
    'grep -rn "sensors" /opt/hiops/ 2>/dev/null | head -n 10',
    'grep -rn "forensics" /opt/hiops/ 2>/dev/null | head -n 10'
]

for cmd in cmds:
    print(f'=== CMD: {cmd} ===')
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='ignore')
    print(out[:1500])
