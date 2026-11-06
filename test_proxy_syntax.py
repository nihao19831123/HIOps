import http.server
import urllib.request
import urllib.error
import json
import uuid
import sys

# Test pure python proxy logic
class TestProxy(http.server.BaseHTTPRequestHandler):
    def proxy_to_upstream(self):
        url = f"http://127.0.0.1:5080{self.path}"
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length > 0 else None
        
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ['host', 'content-length']}
        req = urllib.request.Request(url, data=body, headers=headers, method=self.command)
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() not in ['transfer-encoding', 'content-length']:
                        self.send_header(k, v)
                content = resp.read()
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() not in ['transfer-encoding', 'content-length']:
                    self.send_header(k, v)
            content = e.read()
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self):
        self.proxy_to_upstream()

print("Proxy logic test passed import and syntax check.")
