import os
import struct

def parse_dll_all_strings(dll_path):
    with open(dll_path, 'rb') as f:
        data = f.read()

    strings_idx = data.find(b'#Strings\x00')
    offset = struct.unpack('<I', data[strings_idx-8:strings_idx-4])[0]
    size = struct.unpack('<I', data[strings_idx-4:strings_idx])[0]
    bsjb = data.find(b'BSJB')
    strings_data = data[bsjb+offset:bsjb+offset+size]

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
    return names

names = parse_dll_all_strings(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll")

controllers = ['AgentController', 'AgentHeartbeatController', 'IncidentController', 'DlpController', 'DlpEvidenceController', 'DlpAnalystController']

for c in controllers:
    print(f"\n*** {c} ***")
    # In #Strings, methods of a class appear or action names appear
    matching = [n for n in names if any(m in n for m in ['Heartbeat', 'Command', 'Incident', 'Evidence', 'Agent', 'Event', 'Report', 'Ack', 'Ingest', 'Upload', 'Create', 'Query', 'Get', 'Post'])]
    # Let's filter methods that look like controller actions
    # (usually start with uppercase, don't have < or >)
    actions = [n for n in matching if not n.startswith('<') and not n.startswith('_') and not 'BackingField' in n]
    print("Methods / Action candidates:", sorted(list(set(actions))))
    break
