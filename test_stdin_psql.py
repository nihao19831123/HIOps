import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.114.30', port=22, username='root', password='Admin@123', timeout=5)

py_code = """
import subprocess

sql = '''
DO $$
DECLARE
    v_asset_id uuid;
BEGIN
    SELECT "Id" INTO v_asset_id FROM "Assets" WHERE lower("Hostname") = lower('TEST-39') LIMIT 1;
    INSERT INTO "Incidents" ("Id", "Title", "Status", "Severity", "StartedAt", "RootAssetId", "RootCause", "Confidence", "BusinessImpact", "Summary")
    VALUES ('00000000-0000-0000-0000-000000000039', '终端一键报障: TEST-39 [门诊医生站]', 1, 2, NOW(), v_asset_id, '窗口: 门诊', 0.95, '门诊临床终端异常', '测试报障');
END $$;
'''

p = subprocess.run(["su", "-", "postgres", "-c", "psql -d hiops"], input=sql.encode('utf-8'), capture_output=True)
print("RC:", p.returncode)
print("OUT:", p.stdout.decode())
print("ERR:", p.stderr.decode())
"""

sftp = ssh.open_sftp()
with sftp.file('/tmp/test_stdin_psql.py', 'w') as f:
    f.write(py_code)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('python3 /tmp/test_stdin_psql.py')
print(stdout.read().decode())
print(stderr.read().decode())

# Clean up test row
ssh.exec_command('su - postgres -c "psql -d hiops -c \\"DELETE FROM \\\\\\"Incidents\\\\\\" WHERE \\\\\\"Id\\\\\\" = \'00000000-0000-0000-0000-000000000039\';\\""')
ssh.close()
