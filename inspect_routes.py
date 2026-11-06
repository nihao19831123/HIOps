import os
import re

api_dir = r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api"

def examine(dll_name):
    path = os.path.join(api_dir, dll_name)
    if not os.path.exists(path):
        return
    with open(path, "rb") as f:
        data = f.read()
    print(f"*** {dll_name} ***")
    # Find all api routes
    routes = re.findall(rb"api/v1/[a-zA-Z0-9_\-\{\}/]+", data)
    print("Routes:", sorted(list(set(r.decode('ascii', errors='ignore') for r in routes))))

for name in sorted(os.listdir(api_dir)):
    if name.endswith(".dll") and name.startswith("HIOps"):
        examine(name)
