import urllib.request

for m in ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']:
    url = 'http://192.168.114.30:5080/api/v1/sensors/forensics/report'
    headers = {
        'Content-Type': 'application/json',
        'X-HIOps-Sensor-Token': 'HIOps-Auth-2026-X9',
        'X-HIOps-Agent-Key': 'hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae'
    }
    req = urllib.request.Request(url, data=b'{}' if m in ['POST', 'PUT'] else None, headers=headers, method=m)
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            print(f"{m} -> {resp.status} : {resp.read().decode()[:100]}")
    except urllib.error.HTTPError as e:
        print(f"{m} -> HTTP {e.code} : {e.read().decode()[:100]}")
    except Exception as e:
        print(f"{m} -> Error : {e}")

# Also test without /report or other variations
for test_url in [
    'http://192.168.114.30:5080/api/v1/sensors/forensics',
    'http://192.168.114.30:5080/api/v1/sensors',
    'http://192.168.114.30:5080/api/v1/agents/heartbeat',
    'http://192.168.114.30:5080/api/v1/agents/report',
    'http://192.168.114.30:5080/api/v1/dlp/events'
]:
    req = urllib.request.Request(test_url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            print(f"GET {test_url} -> {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"GET {test_url} -> HTTP {e.code}")
    except Exception as e:
        print(f"GET {test_url} -> Error {e}")
