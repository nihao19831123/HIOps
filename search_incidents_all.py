import urllib.request
import json

headers = {
    'User-Agent': 'Mozilla/5.0',
    'X-HIOps-Agent-Key': 'hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae'
}

for page in range(1, 10):
    url = f'http://192.168.114.30:5080/api/v1/incidents?page={page}&pageSize=100'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        items = data.get('data', {}).get('items', [])
        if not items:
            break
        for it in items:
            title = it.get('title', '')
            summary = it.get('summary', '') or ''
            raw = json.dumps(it, ensure_ascii=False)
            if '20.168' in raw or '168' in title or '一键' in title or '故障' in title or '卡顿' in title or '取证' in title:
                print(f"Page {page} Match: {it}")
