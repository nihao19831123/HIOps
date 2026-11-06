import dnfile
import struct

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe")

# RVA of DrainQueueAsync state machine MoveNext is 0x2ac8
offset = pe.get_offset_from_rva(0x2ac8)
with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe", "rb") as f:
    f.seek(offset)
    code = f.read(500)

us = pe.net.metadata.streams.get(b'#US')
for i in range(len(code)-4):
    if code[i] == 0x72:
        tok = struct.unpack('<I', code[i+1:i+5])[0]
        if (tok >> 24) == 0x70:
            us_off = tok & 0x00FFFFFF
            s = us.get(us_off)
            print(f"ldstr: {repr(s.value)}")
