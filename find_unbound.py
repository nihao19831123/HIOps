import dnfile
import struct

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll")
us = pe.net.metadata.streams.get(b'#US')

for row in pe.net.mdtables.MethodDef:
    name = str(row.Name)
    if name == "MoveNext":
        offset = pe.get_offset_from_rva(row.Rva)
        with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll", "rb") as f:
            f.seek(offset)
            code = f.read(4000)
        strings = []
        for i in range(len(code)-4):
            if code[i] == 0x72:
                tok = struct.unpack('<I', code[i+1:i+5])[0]
                if (tok >> 24) == 0x70:
                    us_off = tok & 0x00FFFFFF
                    s = us.get(us_off)
                    strings.append(s.value)
        if any("unbound" in s.lower() for s in strings):
            print(f"Found MoveNext at RVA {hex(row.Rva)} with strings:")
            for s in strings:
                print(f"  {repr(s)}")
