with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe", "rb") as f:
    data = f.read()

target = "/api/v1/sensors/forensics/report".encode('utf-16le')
idx = data.find(target)
print("Found target string at:", hex(idx))

# Find BSJB and #US
bsjb = data.find(b'BSJB')
import struct
us_idx = data.find(b'#US\x00')
us_offset = struct.unpack('<I', data[us_idx-8:us_idx-4])[0] + bsjb
print("#US starts at:", hex(us_offset))
offset_in_us = idx - 1 - us_offset # 1 byte length prefix
print("Offset in #US:", hex(offset_in_us))

# Now search for 0x70 | offset_in_us
token = 0x70000000 | offset_in_us
token_bytes = struct.pack('<I', token)
print("Token bytes:", token_bytes.hex())

pos = 0
while True:
    p = data.find(token_bytes, pos)
    if p == -1:
        break
    print("Found token at file offset:", hex(p))
    pos = p + 1
