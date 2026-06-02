from pathlib import Path
p=Path('c:/Users/PC/Documents/smart_monitoring_system/lib/screens/cashier/widgets/cart_sheet.dart')
s=p.read_text()
pairs={'(':')','{':'}','[':']'}
stack=[]
for i,ch in enumerate(s):
    if ch in pairs:
        stack.append((ch,i))
    elif ch in pairs.values():
        if not stack:
            print('Unmatched closing', ch, 'at', i)
            break
        open_ch, pos = stack[-1]
        if pairs[open_ch]==ch:
            stack.pop()
        else:
            print('Mismatched', open_ch, 'at', pos, 'with', ch, 'at', i)
            break
else:
    if stack:
        print('Unmatched opens remaining:', len(stack))
        for ch,pos in stack:
            line = s.count('\n',0,pos)+1
            col = pos - s.rfind('\n',0,pos)
            print(f"  {ch} at index {pos} (line {line}, col {col})")
            
            # also print line/col for the mismatched closing if available
            # find first closing brace that caused mismatch
            for j,ch2 in enumerate(s):
                pass
    else:
        print('All balanced')
# show context around reported index if any
if stack:
    ch,pos=stack[-1]
    start=max(0,pos-120)
    end=min(len(s),pos+120)
    print('\nContext around last unmatched open:')
    print(s[start:end])
