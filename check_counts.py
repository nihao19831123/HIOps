import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

sql = '''
SELECT 'BusinessSystems' as tbl, count(*) FROM "BusinessSystems"
UNION ALL SELECT 'BusinessComponents', count(*) FROM "BusinessComponents"
UNION ALL SELECT 'BusinessBindings', count(*) FROM "BusinessBindings"
UNION ALL SELECT 'Incidents', count(*) FROM "Incidents"
UNION ALL SELECT 'IncidentEvents', count(*) FROM "IncidentEvents"
UNION ALL SELECT 'NormalizedEvents', count(*) FROM "NormalizedEvents"
UNION ALL SELECT 'Assets', count(*) FROM "Assets";
'''

sftp = ssh.open_sftp()
with sftp.file('/tmp/count.sql', 'w') as f:
    f.write(sql)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('PGPASSWORD=hiops psql -U hiops -d hiops -h 127.0.0.1 -f /tmp/count.sql')
out = stdout.read().decode('utf-8', errors='ignore')
err = stderr.read().decode('utf-8', errors='ignore')
print("STDOUT:\n", out)
if err:
    print("STDERR:\n", err)
ssh.close()
