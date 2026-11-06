import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)
stdin, stdout, stderr = ssh.exec_command('su - postgres -c "psql -d hiops -c \\"\\dt\\""')
print(stdout.read().decode('utf-8', errors='ignore'))
ssh.close()
