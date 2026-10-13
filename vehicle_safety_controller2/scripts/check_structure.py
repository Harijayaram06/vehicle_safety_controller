#!/usr/bin/env python3
"""Optional technology-independent elaboration/process/latch checks with Yosys."""
import os, pathlib, subprocess
root=pathlib.Path(__file__).resolve().parents[1]; os.chdir(root)
yosys=os.environ.get('YOSYS','yosys')
rtl=pathlib.Path('rtl/files.f').read_text().split()
for name,top,extra in [('baseline','vehicle_safety_top',''),('mlp','mlp_inference',''),('neural_top','vehicle_safety_top','chparam -set USE_MLP 1 vehicle_safety_top;')]:
    command='read_verilog '+' '.join(rtl)+'; '+extra+f' hierarchy -check -top {top}; proc; opt; check -assert; select -assert-none t:$dlatch; stat'
    r=subprocess.run([yosys,'-Q','-T','-p',command],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    pathlib.Path('reports',f'yosys_{name}_check.log').write_text(r.stdout)
    if r.returncode: raise SystemExit(r.stdout)
    print(f'PASS structural check: {name} (no mapped PPA claim)')
