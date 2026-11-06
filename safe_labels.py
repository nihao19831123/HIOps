import re

with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\wwwroot\assets\IncidentView-CUVQ25za.js", "rb") as f:
    data = f.read()

# Let's find labels
labels = re.findall(rb'label:[`\'"]([^`\'"]+)[`\'"]', data)
print("IncidentView labels:")
for l in labels:
    print(" -", l.decode('utf-8', errors='replace'))

with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\wwwroot\assets\AgentHealthView-GoJX53Pi.js", "rb") as f:
    data2 = f.read()
labels2 = re.findall(rb'label:[`\'"]([^`\'"]+)[`\'"]', data2)
print("\nAgentHealthView labels:")
for l in labels2:
    print(" -", l.decode('utf-8', errors='replace'))
