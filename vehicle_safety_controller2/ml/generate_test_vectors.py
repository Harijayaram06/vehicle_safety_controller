#!/usr/bin/env python3
"""Generate deterministic arithmetic fixtures. NO training or accuracy claims."""
from pathlib import Path
import json, random
from reference_inference import infer
ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(20261011)
N = 1024
rows = []
for i in range(N):
    x = [rng.randrange(128) for _ in range(8)]
    model = {'weights': [rng.randrange(-128, 128) for _ in range(108)],
             'biases': [rng.randrange(-20000, 20001) for _ in range(15)], 'margin_min': 256}
    if i == 0:  # Exact score tie.
        model['weights'] = [0]*108; model['biases'] = [0]*15
    if i == 1:  # Legal accumulator extremes and signed score difference.
        model['weights'] = [-128,127]*54
        model['biases'] = [(-1 if j%2 else 1)*(2**20) for j in range(15)]
        x = [127]*8
    if i in (2, 3):
        model['weights'] = [0]*108; model['biases'] = [0]*15
        model['biases'][13] = 255 if i==2 else 256
    if i == 4:
        x = [0]*8
    scores, cls, margin, confident = infer(x, model)
    # One hex row: packed feature bytes, 108 weights, 15 biases, scores, class, margin, confidence.
    packed = sum(v << (8*k) for k,v in enumerate(x))
    row = [f'{packed:016x}'] + [f'{v&255:02x}' for v in model['weights']]
    row += [f'{v&0xffffff:06x}' for v in model['biases']+scores]
    row += [f'{cls:x}', f'{margin:07x}', str(confident)]
    rows.append(' '.join(row))
(ROOT/'vectors/mlp_vectors.txt').write_text('\n'.join(rows)+'\n')
(ROOT/'vectors/manifest.json').write_text(json.dumps({'seed':20261011,'vectors':N,'kind':'arithmetic verification fixtures; not trained models','margin_min':256},indent=2)+'\n')
print(f'Generated {N} arithmetic vectors with independently calculated Python expected scores')
