import urllib.request
import json

headers = {
    'User-Agent': 'Mozilla/5.0',
    'X-HIOps-Agent-Key': 'hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae'
}

url = 'http://192.168.114.30:5080/api/v1/agents/health?pageSize=100'
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=25) as resp:
    data = json.loads(resp.read().decode('utf-8'))
    items = data.get('data', {}).get('items', [])
    print(f'Total health items on 114.30: {len(items)}')
    for it in items:
        host = it.get('hostname')
        ip = it.get('ipAddress')
        score = it.get('healthScore')
        rep = it.get('reportedAt')
        print(f"Host: {host:20} IP: {str(ip):16} Score: {score} Rep: {rep}")
