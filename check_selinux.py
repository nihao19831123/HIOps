import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=10, banner_timeout=30)
cmd = "getenforce"
stdin, stdout, stderr = ssh.exec_command(cmd)
print("SELinux status:", stdout.read().decode())
ssh.close()
