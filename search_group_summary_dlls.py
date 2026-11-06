import os

api_dir = r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api"
for fname in os.listdir(api_dir):
    if fname.endswith(".dll"):
        p = os.path.join(api_dir, fname)
        with open(p, "rb") as f:
            data = f.read()
        if b"group-summary" in data:
            print(f"Found group-summary in {fname}")
