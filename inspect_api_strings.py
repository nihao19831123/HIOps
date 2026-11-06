import os
import struct

def parse_us_stream(dll_path):
    with open(dll_path, 'rb') as f:
        data = f.read()

    idx = data.find(b'#US\x00')
    if idx == -1:
        return []
    offset_in_metadata = struct.unpack('<I', data[idx-8:idx-4])[0]
    size = struct.unpack('<I', data[idx-4:idx])[0]

    bsjb = data.find(b'BSJB')
    us_offset = bsjb + offset_in_metadata

    stream_data = data[us_offset:us_offset+size]
    strings = []
    pos = 1
    while pos < len(stream_data):
        b0 = stream_data[pos]
        if b0 == 0:
            pos += 1
            continue
        if b0 < 0x80:
            length = b0
            pos += 1
        elif (b0 & 0xC0) == 0x80:
            length = ((b0 & 0x3F) << 8) | stream_data[pos+1]
            pos += 2
        else:
            length = ((b0 & 0x1F) << 24) | (stream_data[pos+1] << 16) | (stream_data[pos+2] << 8) | stream_data[pos+3]
            pos += 4
        
        str_bytes = stream_data[pos:pos+length-1]
        pos += length
        try:
            s = str_bytes.decode('utf-16le')
            strings.append(s)
        except:
            pass
    return strings

api_dll = r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll"
strings = parse_us_stream(api_dll)
print(f"Total strings in HIOps.Api.dll: {len(strings)}")
for s in strings:
    if any(k in s.lower() for k in ['heartbeat', 'incident', 'event', 'forensic', 'health', 'sensor', 'agent', 'dlp', 'report', 'evidence']):
        print(' -', repr(s))
