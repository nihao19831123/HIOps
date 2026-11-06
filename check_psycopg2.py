import paramiko, time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=10, banner_timeout=30)
cmd = "python3 -c 'import psycopg2; print(psycopg2.__file__)' 2>&1"
stdin, stdout, stderr = ssh.exec_command(cmd)
print("Result of psycopg2 check:", stdout.read().decode())
ssh.close()
