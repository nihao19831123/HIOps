import dnfile
import struct

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll")
offset = pe.get_offset_from_rva(0x178e4)

with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll", "rb") as f:
    f.seek(offset)
    code = f.read(1500)

us = pe.net.metadata.streams.get(b'#US')
tokens = []
for i in range(len(code)-4):
    if code[i] == 0x72:
        tok = struct.unpack('<I', code[i+1:i+5])[0]
        if (tok >> 24) == 0x70:
            us_off = tok & 0x00FFFFFF
            s = us.get(us_off)
            print(f"String: {repr(s.value)}")
