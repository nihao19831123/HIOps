import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

sql = "SELECT \"MigrationId\" FROM \"__EFMigrationsHistory\" ORDER BY 1;"
stdin, stdout, stderr = ssh.exec_command('PGPASSWORD=hiops psql -U hiops -d hiops -h 127.0.0.1 -c "SELECT * FROM \\"__EFMigrationsHistory\\";"')
print(stdout.read().decode('utf-8', errors='ignore'))
print(stderr.read().decode('utf-8', errors='ignore'))
ssh.close()
