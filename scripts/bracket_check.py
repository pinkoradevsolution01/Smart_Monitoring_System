import sys
from pathlib import Path
p = Path(r"c:\Users\PC\Documents\smart_monitoring_system\lib\screens\cashier\price_checker_screen.dart")
s = p.read_text()
pairs = {'(':')','{':'}','[':']'}
stack=[]
for i,ch in enumerate(s, start=1):
    if ch in pairs:
        stack.append((ch,i))
    elif ch in pairs.values():
        if not stack:
            print(f"Unmatched closing {ch} at {i}")
            sys.exit(0)
        last, pos = stack.pop()
        if pairs[last] != ch:
            print(f"Mismatched: {last} at {pos} vs {ch} at {i}")
            sys.exit(0)
if stack:
    for ch,pos in stack:
        print(f"Unclosed {ch} at {pos}")
else:
    print('All balanced')
