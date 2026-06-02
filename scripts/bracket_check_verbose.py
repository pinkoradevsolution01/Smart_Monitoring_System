from pathlib import Path
p = Path(r"c:\Users\PC\Documents\smart_monitoring_system\lib\screens\admin\business_registration_screen.dart")
s = p.read_text()
pairs = {'(':')','{':'}','[':']'}
stack=[]
for idx,ch in enumerate(s, start=1):
    if ch in pairs:
        stack.append((ch,idx))
    elif ch in pairs.values():
        if not stack:
            print(f"Unmatched closing {ch} at idx {idx}")
            break
        last,pos = stack.pop()
        if pairs[last] != ch:
            # report
            def idx_to_linecol(i):
                lines = s.splitlines(keepends=True)
                cur=0
                for lineno,l in enumerate(lines, start=1):
                    cur += len(l)
                    if cur >= i:
                        col = i - (cur - len(l))
                        return lineno,col
                return -1,-1
            l1,c1 = idx_to_linecol(pos)
            l2,c2 = idx_to_linecol(idx)
            print(f"MISMATCH: opening {last} at idx {pos} -> line {l1},col {c1}")
            print(f"         closing {ch} at idx {idx} -> line {l2},col {c2}")
            # show snippet around both
            def snippet(line, radius=3):
                lines = s.splitlines()
                start = max(0, line-1-radius)
                end = min(len(lines), line-1+radius+1)
                return '\n'.join(f"{i+1}: {lines[i]}" for i in range(start,end))
            print('\nOPENING CONTEXT:\n'+snippet(l1))
            print('\nCLOSING CONTEXT:\n'+snippet(l2))
            break
else:
    if stack:
        print('Unclosed openings:')
        for ch,pos in stack:
            print(ch,pos)
    else:
        print('All balanced')
