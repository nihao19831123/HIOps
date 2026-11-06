import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

sql = '''
SELECT 'AgentHeartbeats' as tbl, count(*), max("ReportedAt")::text FROM "AgentHeartbeats" WHERE "IpAddress" = '192.168.39.11'
UNION ALL
SELECT 'NormalizedEvents', count(*), max("Timestamp")::text FROM "NormalizedEvents" WHERE "Description" LIKE '%39.11%' OR "Title" LIKE '%39.11%'
UNION ALL
SELECT 'Incidents', count(*), max("StartedAt")::text FROM "Incidents" WHERE "Title" LIKE '%39.11%' OR "Summary" LIKE '%39.11%';
'''

sftp = ssh.open_sftp()
with sftp.file('/tmp/check_39.sql', 'w') as f:
    f.write(sql)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('PGPASSWORD=hiops psql -U hiops -d hiops -h 127.0.0.1 -f /tmp/check_39.sql')
print("OUT:\n", stdout.read().decode('utf-8', errors='ignore'))
print("ERR:\n", stderr.read().decode('utf-8', errors='ignore'))
ssh.close()
