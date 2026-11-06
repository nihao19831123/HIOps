import urllib.request
import json

url = 'http://192.168.114.30:5080/api/v1/sensors/forensics/report'
headers = {
    'Content-Type': 'application/json',
    'X-HIOps-Sensor-Token': 'HIOps-Auth-2026-X9',
    'X-HIOps-Agent-Key': 'hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae'
}

req = urllib.request.Request(url, data=b'{}', headers=headers, method='POST')
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        print("Status:", resp.status)
        print("Body:", resp.read().decode())
except urllib.error.HTTPError as e:
    print(f"HTTPError: {e.code} - {e.read().decode()}")
except Exception as e:
    print("Error:", e)
