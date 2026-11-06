import os

api_dir = r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api"

for fname in os.listdir(api_dir):
    if fname.endswith(".dll"):
        p = os.path.join(api_dir, fname)
        with open(p, "rb") as f:
            d = f.read()
        for kw in [b"Forensic", b"forensic", b"MANUAL_HOTKEY", b"UI_HANG", b"ActionTrail"]:
            if kw in d:
                print(f"Found {kw} in {fname}")
