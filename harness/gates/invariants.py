"""invariants.py SCAN.json... — checks the SPEC contracts that tool output alone can decide.
I1 (identity): a high edge's callee is a defined node. I2 (C7): no empty caller or callee, no <global> placeholder caller.
Exit status 1 when any violation is found."""
import json, sys, collections
def check(path):
    cg = json.load(open(path))['call_graph']
    nodes = set(cg.get('nodes') or [])
    e = cg['edges']
    bad = collections.Counter(); ex = {}
    for x in e:
        if not x['caller_id'] or not x['callee_id'] or x['caller_id'] == '<global>':
            bad['I2 empty id'] += 1; ex.setdefault('I2 empty id', x)
        if x['confidence'] == 'high' and x['callee_id'] not in nodes:
            bad['I1 high callee undefined'] += 1; ex.setdefault('I1 high callee undefined', x)
    return len(e), len(nodes), bad, ex
if __name__ == '__main__':
    failed = False
    for p in sys.argv[1:]:
        if not __import__('os').path.exists(p): print('MISSING', p); continue
        n, nn, bad, ex = check(p)
        print(f"{p.split('/')[-1]:40} edges={n:7} nodes={nn:6} " + ' '.join(f'{k}={v}' for k, v in bad.items()))
        for k, x in ex.items():
            print('    e.g.', k, x['caller_id'], '->', x['callee_id'], x['confidence'], x['call_type'])
        failed = failed or bool(bad)
    sys.exit(1 if failed else 0)
