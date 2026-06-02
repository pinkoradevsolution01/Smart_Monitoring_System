from pathlib import Path
p = Path(r"c:\Users\PC\Documents\smart_monitoring_system\lib\screens\admin\business_registration_screen.dart")
lines = p.read_text().splitlines()
for i in range(max(0,len(lines)-50), len(lines)):
    print(f"{i+1:4}: {lines[i]}")
