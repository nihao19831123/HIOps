import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

sql = 'SELECT * FROM "BusinessSystems"; SELECT * FROM "BusinessComponents"; SELECT * FROM "BusinessBindings";'

sftp = ssh.open_sftp()
with sftp.file('/tmp/biz.sql', 'w') as f:
    f.write(sql)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('PGPASSWORD=hiops psql -U hiops -d hiops -h 127.0.0.1 -f /tmp/biz.sql')
print(stdout.read().decode('utf-8', errors='ignore'))
ssh.close()
