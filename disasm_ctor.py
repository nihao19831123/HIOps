import dnfile

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe")

# Let's inspect ForensicOrchestrator constructor
# RVA is 0x48f8
offset = pe.get_offset_from_rva(0x48f8)
with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe", "rb") as f:
    f.seek(offset)
    code = f.read(150)

# Disassemble IL instructions
import struct
us = pe.net.metadata.streams.get(b'#US')
strings = pe.net.metadata.streams.get(b'#Strings')

print("Offset:", hex(offset))
# Let's find all ldstr in this constructor
for i in range(len(code)-4):
    if code[i] == 0x72:
        tok = struct.unpack('<I', code[i+1:i+5])[0]
        if (tok >> 24) == 0x70:
            us_off = tok & 0x00FFFFFF
            s = us.get(us_off)
            print(f"ldstr: {repr(s.value)}")
