#!/usr/bin/env python3
"""Bit-accurate 8-8-4-3 inference. Standard-library-only; this is not a trainer."""
import json

def validate(model):
    w, b = model['weights'], model['biases']
    assert len(w) == 108 and len(b) == 15, 'Expected 108 weights and 15 biases'
    assert all(type(v) is int and -128 <= v <= 127 for v in w), 'Invalid weight'
    assert all(type(v) is int and abs(v) <= 2**20 for v in b), 'Invalid bias'
    assert type(model['margin_min']) is int and 1 <= model['margin_min'] < 2**25

def infer(features, model):
    validate(model)
    assert len(features) == 8 and all(type(x) is int and 0 <= x <= 127 for x in features)
    w, b = model['weights'], model['biases']
    a = features[:]
    wi = bi = 0
    for nin, nout, hidden in [(8, 8, True), (8, 4, True), (4, 3, False)]:
        out = []
        for _ in range(nout):
            acc = b[bi] + sum(a[k] * w[wi+k] for k in range(nin))
            assert -(2**23) <= acc < 2**23
            out.append(max(0, min(127, acc >> 7)) if hidden else acc)
            wi += nin
            bi += 1
        a = out
    order = sorted(range(3), key=lambda i: (-a[i], i))
    margin = a[order[0]] - a[order[1]]
    return a, order[0], margin, int(margin > 0 and margin >= model['margin_min'])

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(); ap.add_argument('model'); ap.add_argument('features', nargs=8, type=int)
    args = ap.parse_args()
    print(json.dumps(infer(args.features, json.load(open(args.model))), indent=2))
