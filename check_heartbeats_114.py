import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

sql = '''
SELECT DISTINCT "Hostname", "IpAddress", max("ReportedAt") as latest
FROM "AgentHeartbeats"
GROUP BY "Hostname", "IpAddress"
ORDER BY latest DESC
LIMIT 15;
'''

sftp = ssh.open_sftp()
with sftp.file('/tmp/recent_heartbeats.sql', 'w') as f:
    f.write(sql)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('PGPASSWORD=hiops psql -U hiops -d hiops -h 127.0.0.1 -f /tmp/recent_heartbeats.sql')
print(stdout.read().decode('utf-8', errors='ignore'))
ssh.close()
