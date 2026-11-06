import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

sql = '''
SELECT 'Heartbeats' as src, "Hostname", "IpAddress" FROM "AgentHeartbeats" WHERE "IpAddress" LIKE '%39.%' OR "Hostname" LIKE '%39%'
UNION ALL
SELECT 'Identities' as src, "AssetId"::text, "IdentityValue" FROM "AssetIdentities" WHERE "IdentityValue" LIKE '%39.%'
UNION ALL
SELECT 'NetworkObserved' as src, "SwitchHost", "Ip" FROM "NetworkObservedHosts" WHERE "Ip" LIKE '%39.%';
'''

sftp = ssh.open_sftp()
with sftp.file('/tmp/search_39.sql', 'w') as f:
    f.write(sql)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('PGPASSWORD=hiops psql -U hiops -d hiops -h 127.0.0.1 -f /tmp/search_39.sql')
print(stdout.read().decode('utf-8', errors='ignore'))
ssh.close()
