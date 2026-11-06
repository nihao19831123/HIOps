import urllib.request
import json

headers = {
    'User-Agent': 'Mozilla/5.0',
    'X-HIOps-Agent-Key': 'hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae'
}

url = 'http://192.168.114.30:5080/api/v1/agents/health?search=XXK007'
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=10) as resp:
    data = json.loads(resp.read().decode('utf-8'))
    print("Search XXK007 in Health:")
    for it in data.get('data', {}).get('items', []):
        print(" ", it)

url2 = 'http://192.168.114.30:5080/api/v1/agents/health?search=192.168.20.168'
req2 = urllib.request.Request(url2, headers=headers)
with urllib.request.urlopen(req2, timeout=10) as resp:
    data2 = json.loads(resp.read().decode('utf-8'))
    print("\nSearch 192.168.20.168 in Health:")
    for it in data2.get('data', {}).get('items', []):
        print(" ", it)
