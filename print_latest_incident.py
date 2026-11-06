import urllib.request
import json

headers = {'X-HIOps-Agent-Key': 'hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae'}
url = 'http://192.168.114.30:5080/api/v1/incidents?page=1&pageSize=1'

req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=5) as resp:
    data = json.loads(resp.read().decode('utf-8'))
    first = data.get('data', {}).get('items', [])[0]
    print(json.dumps(first, indent=2, ensure_ascii=False))
