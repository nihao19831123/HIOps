import dnfile
import struct

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll")

for row in pe.net.mdtables.MethodDef:
    name = str(row.Name)
    # Check Rva
    # Let's find MoveNext of <GetGroupSummary>d__11
    pass

for type_row in pe.net.mdtables.TypeDef:
    if "<GetGroupSummary>d__11" == str(type_row.TypeName):
        print(f"Found TypeDef {type_row.TypeName}")
        # Methods list
        for method in type_row.methods:
            print(f"  Method {method.Name} RVA: {hex(method.Rva)}")
            if method.Name == "MoveNext":
                offset = pe.get_offset_from_rva(method.Rva)
                with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll", "rb") as f:
                    f.seek(offset)
                    code = f.read(2500)
                us = pe.net.metadata.streams.get(b'#US')
                for i in range(len(code)-4):
                    if code[i] == 0x72:
                        tok = struct.unpack('<I', code[i+1:i+5])[0]
                        if (tok >> 24) == 0x70:
                            us_off = tok & 0x00FFFFFF
                            s = us.get(us_off)
                            print(f"    String: {repr(s.value)}")
