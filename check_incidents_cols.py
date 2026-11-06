import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

sql = "SELECT column_name, data_type, character_maximum_length FROM information_schema.columns WHERE table_name = 'Incidents';"
stdin, stdout, stderr = ssh.exec_command(f'su - postgres -c "psql -d hiops -c \\"{sql}\\""')
print(stdout.read().decode('utf-8', errors='ignore'))
ssh.close()
