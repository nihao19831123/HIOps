import dnfile

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe")
rva = pe.get_rva_from_offset(0x2b3e)
print("RVA of 0x2b3e:", hex(rva))

# Find which method contains this RVA
for row in pe.net.mdtables.MethodDef:
    method_rva = row.Rva
    if method_rva <= rva < method_rva + 0x200:
        print(f"Method: {row.Name} (Method RVA: {hex(method_rva)})")
