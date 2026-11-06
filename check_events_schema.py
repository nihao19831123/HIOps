with open(r'C:\Users\wufeng\Documents\HIOps-发布版-20261021\hiops.sql', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if 'TABLE public.' in l and 'NormalizedEvents' in l:
        print(''.join(lines[i:i+25]))
        break
