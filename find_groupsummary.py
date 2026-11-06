import dnfile

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll")

for row in pe.net.mdtables.MethodDef:
    name = str(row.Name)
    if "GroupSummary" in name:
        print(f"Method: {name} RVA: {hex(row.Rva)}")

for row in pe.net.mdtables.TypeDef:
    name = str(row.Name)
    if "Incident" in name:
        print(f"TypeDef: {name}")
