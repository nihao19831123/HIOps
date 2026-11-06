import re

with open(r'C:\Users\wufeng\Documents\HIOps-发布版-20261021\hiops.sql', 'r', encoding='utf-8') as f:
    text = f.read()

m = re.search(r'COPY public\."BusinessSystems"[^\n]*\n(.*?)\\\.', text, re.DOTALL)
if m:
    print('BusinessSystems data:\n', m.group(1))

m2 = re.search(r'COPY public\."BusinessComponents"[^\n]*\n(.*?)\\\.', text, re.DOTALL)
if m2:
    print('BusinessComponents lines:\n', len(m2.group(1).splitlines()))

m3 = re.search(r'COPY public\."BusinessBindings"[^\n]*\n(.*?)\\\.', text, re.DOTALL)
if m3:
    print('BusinessBindings lines:\n', len(m3.group(1).splitlines()))
