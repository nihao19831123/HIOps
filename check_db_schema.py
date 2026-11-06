import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=10, banner_timeout=30)
cmd = "PGPASSWORD=hiops psql -h 127.0.0.1 -U hiops -d hiops -c '\d \"Incidents\"'"
stdin, stdout, stderr = ssh.exec_command(cmd)
print("Incidents columns:")
print(stdout.read().decode())

cmd2 = "PGPASSWORD=hiops psql -h 127.0.0.1 -U hiops -d hiops -c '\d \"NormalizedEvents\"'"
stdin, stdout, stderr = ssh.exec_command(cmd2)
print("NormalizedEvents columns:")
print(stdout.read().decode())
ssh.close()
