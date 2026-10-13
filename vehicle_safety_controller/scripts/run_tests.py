#!/usr/bin/env python3
"""Run portable self-checking simulation from any working directory."""
import os, sys, subprocess, pathlib, shutil, json, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT); pathlib.Path('build').mkdir(exist_ok=True); pathlib.Path('reports').mkdir(exist_ok=True)
backend=sys.argv[1] if len(sys.argv)>1 else 'iverilog'
pathlib.Path('reports/verification_summary.json').unlink(missing_ok=True)
subprocess.run([sys.executable,'ml/generate_test_vectors.py'],check=True)
tests=['tb_monitor','tb_policy','tb_controller','tb_mlp','tb_neural_adapter','tb_features','tb_fsm']
rtl=pathlib.Path('rtl/files.f').read_text().split()
results=[]
for top in tests:
    if not pathlib.Path('tb',top+'.sv').is_file(): raise SystemExit(f'Missing required testbench: {top}')
    if backend=='iverilog':
        compiler=os.environ.get('IVERILOG','iverilog'); runner=os.environ.get('VVP','vvp')
        cmd=[compiler,'-g2012','-Wall','-s',top,'-o',f'build/{top}.vvp',*rtl,f'tb/{top}.sv']
        if os.environ.get('IVERILOG_BASE'): cmd[1:1]=['-B',os.environ['IVERILOG_BASE']]
        compile_result=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        pathlib.Path('reports',top+'_compile.log').write_text(compile_result.stdout)
        if compile_result.returncode: print(compile_result.stdout); raise SystemExit(compile_result.returncode)
        cmd=[runner,f'build/{top}.vvp']
        if top=='tb_controller': cmd+=['+WAVES']
    elif backend=='xcelium':
        cmd=['xrun','-64bit','-sv','-access','+rwc','-top',top,'-f','rtl/files.f',f'tb/{top}.sv',
             '-xmlibdirname',f'build/xcelium_{top}','-l',f'reports/{top}_xrun.log']
        if top=='tb_controller': cmd+=['+WAVES']
    else: raise SystemExit('Choose iverilog or xcelium')
    r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    pathlib.Path('reports',top+'.log').write_text(r.stdout)
    print(r.stdout.strip())
    passed=r.returncode==0 and f'PASS {top}' in r.stdout
    results.append({'test':top,'passed':passed,'returncode':r.returncode})
    if not passed: raise SystemExit(f'FAILED {top}; inspect reports/{top}.log')
pathlib.Path('reports/verification_summary.json').write_text(json.dumps({'backend':backend,'results':results,'all_passed':all(r['passed'] for r in results)},indent=2)+'\n')
print('ALL TESTBENCHES PASSED (not a code-coverage or formal-proof claim)')
