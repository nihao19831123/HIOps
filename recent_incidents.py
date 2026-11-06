import urllib.request
import json

headers = {
    'User-Agent': 'Mozilla/5.0',
    'X-HIOps-Agent-Key': 'hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae'
}

url = 'http://192.168.114.30:5080/api/v1/incidents?page=1&pageSize=30'
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=15) as resp:
    data = json.loads(resp.read().decode('utf-8'))
    items = data.get('data', {}).get('items', [])
    print(f"Total incidents on page 1: {len(items)}")
    for it in items:
        iid = it.get('id')
        title = it.get('title')
        started = it.get('startedAt')
        status = it.get('status')
        sev = it.get('severity')
        summary = it.get('summary')
        print(f"[{started}] ({sev}) {title} | Status: {status}")
        if summary:
            print(f"   Summary: {summary}")
