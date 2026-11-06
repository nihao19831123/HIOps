import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123')

cmds = [
    'ls -la /opt/hiops/api',
    'find /opt /root /var -name "*forensic*" -o -name "*Forensic*" 2>/dev/null',
    'find /opt /root /var -name "*sensor*" -o -name "*Sensor*" 2>/dev/null | head -n 30'
]

for cmd in cmds:
    print(f'=== CMD: {cmd} ===')
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='ignore')
    print(out[:1500])
