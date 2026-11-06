import dnfile

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe")

# Let's inspect ForensicOrchestrator fields and Program.Main
for row in pe.net.mdtables.TypeDef:
    if row.Name == "ForensicOrchestrator":
        print(f"TypeDef: {row.Name}")
        # Print fields
        for f in pe.net.mdtables.Field:
            # Let's check fields
            pass

# Let's read the code around RVA 0x48f8
offset = pe.get_offset_from_rva(0x48f8)
with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe", "rb") as f:
    f.seek(offset)
    raw = f.read(150)
print("Bytes of ForensicOrchestrator .ctor:", raw.hex())
