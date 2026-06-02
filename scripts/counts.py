from pathlib import Path
p = Path(r"c:\Users\PC\Documents\smart_monitoring_system\lib\screens\admin\business_registration_screen.dart")
s = p.read_text()
for ch in ['(',')','{','}','[',']']:
    print(f"{ch}: {s.count(ch)}")
