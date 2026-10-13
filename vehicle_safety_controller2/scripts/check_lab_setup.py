#!/usr/bin/env python3
"""Check the recovered UART PDK profile; no proprietary data is copied."""
import argparse, os, re, sys
from pathlib import Path
DEFAULT = '/home/cadence/install/FOUNDRY/digital/90nm/dig'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--stage', choices=['synth', 'pnr'], default='pnr')
p.add_argument('--pdk-root', default=os.environ.get('VSC_PDK_ROOT', DEFAULT))
a = p.parse_args()
root = Path(a.pdk_root)
files = {'slow': root/'lib/slow.lib', 'fast': root/'lib/fast.lib'}
if a.stage == 'pnr':
    files.update(lef=root/'lef/gsclib090_translated.lef',
                 captable=root/'captable/gpdk090.lef.extended.CapTbl',
                 qrc=root/'qrc/gpdk090_9l.tch')
errors = []
contents = {}
for key, path in files.items():
    try:
        if not path.is_file() or path.stat().st_size == 0:
            raise OSError('missing or empty')
        with path.open('rb') as f:
            f.read(1)
        print('OK', key, path)
        if key in ('slow', 'fast', 'lef'):
            contents[key] = path.read_text(errors='replace')
    except OSError as e:
        errors.append(str(path) + ': ' + str(e))
for key in ('slow', 'fast'):
    if key not in contents:
        continue
    unit = re.search(r'time_unit\s*:\s*"([^"]+)"', contents[key])
    print(key, 'time_unit:', unit.group(1) if unit else 'NOT FOUND')
    if not unit or unit.group(1).replace(' ', '').lower() != '1ns':
        errors.append(key + ': verify time units before using the 50 ns SDC')
if a.stage == 'pnr':
    required = ['CLKBUF' + x for x in ('X2','X3','X4','X6','X8','X12','X16','X20')]
    required += ['CLKINV' + x for x in ('X1','X2','X3','X4','X6','X8','X12','X16','X20')]
    for key in ('slow', 'fast'):
        if key in contents:
            cells = set(re.findall(r'\bcell\s*\(\s*"?([A-Za-z0-9_]+)', contents[key]))
            absent = sorted(set(required) - cells)
            if absent:
                errors.append(key + ': missing configured CTS cells: ' + ', '.join(absent))
    if 'lef' in contents:
        lef = contents['lef']
        for token in ['SITE gsclib090site'] + ['LAYER Metal' + str(n) for n in range(1,10)] + ['MACRO '+n for n in required]:
            if not re.search(r'\b' + r'\s+'.join(map(re.escape, token.split())) + r'\b', lef):
                errors.append('LEF missing ' + token)
local = Path(__file__).resolve().parents[1]/'cadence/gpdk090/local_config.tcl'
if local.exists():
    print('NOTE: local_config.tcl exists. This Python check uses the recovered root profile; review custom Tcl overrides separately.')
for msg in errors:
    print('ERROR:', msg, file=sys.stderr)
if errors:
    sys.exit(1)
print('Profile files checked. This is not a Cadence import, license, timing or physical verification test.')
