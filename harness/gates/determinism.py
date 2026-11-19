"""determinism.py DIR_A DIR_B [names...] — contract C6: the same tool build on the same
source gives identical edge and node multisets. Prints per-repo result; exit 1 on any diff."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import load_scan, edges, nodes
a, b = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or sorted(f[:-len('.v2.json')] for f in os.listdir(b) if f.endswith('.v2.json'))
bad = 0
for n in names:
    pa, pb = os.path.join(a, n + '.v2.json'), os.path.join(b, n + '.v2.json')
    try: sa, sb = load_scan(pa), load_scan(pb)
    except FileNotFoundError as e: print(f'{n:36} MISSING {e.filename}'); bad += 1; continue
    ea, eb = edges(sa), edges(sb); na, nb = nodes(sa), nodes(sb)
    d = sum((ea - eb).values()) + sum((eb - ea).values()); dn = len(na ^ nb)
    print(f'{n:36} {"OK" if not d and not dn else "DIFF"} edges {sum(ea.values())}/{sum(eb.values())} edge-diff {d} node-diff {dn}')
    bad += bool(d or dn)
print('repos differing:', bad); sys.exit(1 if bad else 0)
