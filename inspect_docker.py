import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123')

cmds = [
    'docker port hiops-api-cn',
    'docker inspect hiops-api-cn --format "{{json .NetworkSettings.Ports}}"',
    'docker inspect hiops-api-cn --format "{{json .Config.Env}}"',
    'netstat -tlpn'
]

for cmd in cmds:
    print(f'=== CMD: {cmd} ===')
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='ignore')
    print(out)
