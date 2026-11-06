import re

with open(r'C:\Users\wufeng\Documents\HIOps-发布版-20261021\hiops.sql', 'r', encoding='utf-8') as f:
    text = f.read()

for tbl in ['BusinessSystems', 'BusinessComponents', 'BusinessBindings']:
    pattern = r'CREATE TABLE public\."' + tbl + r'"\s*\([^;]+?\);'
    m = re.search(pattern, text, re.DOTALL)
    if m:
        print(m.group(0))
        print('='*50)

# Check INSERT statements
for tbl in ['BusinessSystems', 'BusinessComponents', 'BusinessBindings']:
    inserts = re.findall(r'COPY public\."' + tbl + r'".*?\\\.', text, re.DOTALL)
    if not inserts:
        inserts = re.findall(r'INSERT INTO public\."' + tbl + r'".*?;', text, re.DOTALL)
    print(tbl, "data blocks count:", len(inserts))
