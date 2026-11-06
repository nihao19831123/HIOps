import re

def inspect_view(path):
    with open(path, 'rb') as f:
        raw = f.read()
    try:
        text = raw.decode('gbk')
    except:
        text = raw.decode('utf-8', errors='ignore')
    print(f"=== {path} ===")
    labels = re.findall(r'label:[`\'"]([^`\'"]+)[`\'"]', text)
    print("Labels:", labels)
    chinese = re.findall(r'[\u4e00-\u9fa5]{2,}', text)
    print("Chinese texts (first 30):", chinese[:30])

inspect_view(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\wwwroot\assets\IncidentView-CUVQ25za.js")
inspect_view(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\wwwroot\assets\AgentHealthView-GoJX53Pi.js")
