import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)
stdin, stdout, stderr = ssh.exec_command('grep -C 3 "GlobalExceptionMiddleware" /var/log/hiops/api.log | tail -n 20')
print(stdout.read().decode('utf-8', errors='ignore'))
ssh.close()
