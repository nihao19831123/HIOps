import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', banner_timeout=30)

stdin, stdout, stderr = ssh.exec_command('cat /etc/systemd/system/hiops-api.service')
print("hiops-api.service:")
print(stdout.read().decode())

stdin, stdout, stderr = ssh.exec_command('ps aux | grep HIOps.Api')
print("\nps aux | grep HIOps.Api:")
print(stdout.read().decode())
