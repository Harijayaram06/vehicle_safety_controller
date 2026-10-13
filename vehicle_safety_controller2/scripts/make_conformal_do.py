#!/usr/bin/env python3
"""Generate native Conformal commands with paths on YOUR server."""
import argparse, os
from pathlib import Path
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--stage', choices=['synth','route'], default='synth')
p.add_argument('--lib', help='Override slow.lib when local_config.tcl changes its path')
a = p.parse_args()
r = Path(__file__).resolve().parents[1]
lib = Path(a.lib) if a.lib else Path(os.environ.get('VSC_PDK_ROOT', '/home/cadence/install/FOUNDRY/digital/90nm/dig'))/'lib/slow.lib'
net = r/'outputs/gpdk090'/('controller_mapped.v' if a.stage == 'synth' else 'controller_routed.v')
rtl = [r/x.strip() for x in (r/'rtl/files.f').read_text().splitlines() if x.strip() and not x.lstrip().startswith('#')]
for f in [lib, net] + rtl:
    if not f.is_file() or f.stat().st_size == 0:
        p.error('Missing/empty file: ' + str(f))
def q(path):
    s = str(path.resolve())
    if any(c in s for c in ['"', '\n', '\r', '$', '`', '\\']):
        p.error('Unsupported character in path: ' + s)
    return '"' + s + '"'
lines = [
    '// Native Conformal do-file. Default RTL parameters: USE_MONITOR=1, USE_MLP=0.',
    'read library -liberty ' + q(lib) + ' -both',
    'read design ' + ' '.join(q(f) for f in rtl) + ' -Verilog -Golden',
    'read design ' + q(net) + ' -Verilog -Revised',
    'set root module vehicle_safety_top -both',
    'set system mode lec',
    'add compared points -all',
    'compare',
    'report verification -compare_result',
    'report statistics',
]
out = r/'build/gpdk090'/('conformal_' + a.stage + '.do')
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text('\n'.join(lines) + '\n')
print('Generated:', out)
print('Run from project root: lec -nogui -dofile build/gpdk090/conformal_' + a.stage + '.do')
print('Inspect equivalence, unmapped points and aborts; command completion alone is not a proof.')
