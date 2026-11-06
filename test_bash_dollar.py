import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

# Test what bash does with DO $$ inside double quotes
cmd = 'su - postgres -c "echo \\"DO $$ BEGIN NULL; END $$;\\""'
stdin, stdout, stderr = ssh.exec_command(cmd)
print("Result of echo DO $$:")
print(stdout.read().decode())
ssh.close()
