import dnfile
import struct

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe")

offset = pe.get_offset_from_rva(0x4960)

with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe", "rb") as f:
    f.seek(offset)
    code = f.read(2000)

tokens = []
for i in range(len(code)-4):
    if code[i] == 0x72: # ldstr opcode
        token = struct.unpack('<I', code[i+1:i+5])[0]
        if (token >> 24) == 0x70:
            tokens.append((i, token))

us_stream = pe.net.metadata.streams.get(b'#US')
for idx, token in tokens:
    us_offset = token & 0x00FFFFFF
    s = us_stream.get(us_offset)
    print(f"  String at {idx}: {repr(s.value)}")
