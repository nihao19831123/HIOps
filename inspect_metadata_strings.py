import os
import struct

def read_dotnet_types(dll_path):
    with open(dll_path, 'rb') as f:
        data = f.read()

    # Find string stream #Strings
    strings_idx = data.find(b'#Strings\x00')
    if strings_idx == -1:
        return
    offset_in_metadata = struct.unpack('<I', data[strings_idx-8:strings_idx-4])[0]
    size = struct.unpack('<I', data[strings_idx-4:strings_idx])[0]
    bsjb = data.find(b'BSJB')
    strings_offset = bsjb + offset_in_metadata
    strings_data = data[strings_offset:strings_offset+size]

    # Extract all null-terminated strings from #Strings
    pos = 0
    names = []
    current = []
    for b in strings_data:
        if b == 0:
            if current:
                try:
                    names.append(bytes(current).decode('utf-8'))
                except:
                    pass
                current = []
        else:
            current.append(b)

    controllers = [n for n in names if 'Controller' in n]
    actions = [n for n in names if any(prefix in n for prefix in ['Get', 'Post', 'Heartbeat', 'Report', 'Incident', 'Event', 'Health', 'Evidence', 'Dlp'])]
    print("Controllers:", controllers)
    print("Sample actions/methods:", actions[:40])

read_dotnet_types(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll")
