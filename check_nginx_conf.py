import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=10, banner_timeout=30)
cmd = "cat /etc/nginx/nginx.conf | head -n 45"
stdin, stdout, stderr = ssh.exec_command(cmd)
print("nginx.conf head:")
print(stdout.read().decode())
ssh.close()
