import dnfile

pe = dnfile.dnPE(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe")

# Print all MethodDefs and their signatures/RVA
print("=== Methods in HIOps.EndpointSensor.exe ===")
for row in pe.net.mdtables.MethodDef:
    print(f"Method: {row.Name} (RVA: {hex(row.Rva)})")

# Print user strings
print("=== User Strings in HIOps.EndpointSensor.exe ===")
us_stream = pe.net.metadata.streams.get(b'#US')
if us_stream:
    # dnfile provides access to stream
    pass
