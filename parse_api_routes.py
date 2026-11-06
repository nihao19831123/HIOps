import os
import re

# Let's inspect all controller classes and action methods in HIOps.Api.dll
with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api\HIOps.Api.dll", "rb") as f:
    data = f.read()

# Let's find all [HttpGet(...)] and [HttpPost(...)] in the dll
# We can search for the route patterns and method names in metadata
# Or extract all string literals in the controller files
with open(r"C:\Users\wufeng\Documents\HIOps-发布版-20261021\api_strings.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

print("API strings related to routes or paths:")
for line in lines:
    line = line.strip()
    if any(line.startswith(prefix) for prefix in ['api/', '/api/', 'agents', 'dlp', 'incidents', 'assets', 'logs', 'business', 'topology', 'changes']):
        print(" ", line)
