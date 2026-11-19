"""freeze.py OUT_DIR TOOL_COMMIT [names...] — copies the current fanout scans of the
reviewed (h-/s-) repos, gzipped, into OUT_DIR with MANIFEST.json: tool commit, per-repo
sha256 of the edge/node multiset, edge counts, and the census each repo was approved at."""
import sys, os, json, gzip, hashlib, shutil
sys.path.insert(0, os.path.dirname(__file__))
from common import load_scan, edges, nodes, repos, FANOUT
out, commit = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or sorted(n for n in repos(FANOUT) if n[:2] in ('h-', 's-'))
os.makedirs(out, exist_ok=True)
acc = json.load(open(os.path.join(FANOUT, 'ACCURACY.json')))
census = {}
for lang, v in acc['languages'].items():
    census.update(v.get('repo_precision', {}))
man = {'tool_commit': commit, 'repos': {}}
for n in names:
    src = os.path.join(FANOUT, n + '.v2.json')
    s = load_scan(src)
    e, nd = edges(s), nodes(s)
    h = hashlib.sha256(json.dumps([sorted(e.items()), sorted(nd)]).encode()).hexdigest()
    with open(src, 'rb') as fi, gzip.open(os.path.join(out, n + '.v2.json.gz'), 'wb') as fo:
        shutil.copyfileobj(fi, fo)
    man['repos'][n] = {'language': repos(FANOUT)[n][0], 'edges': sum(e.values()), 'nodes': len(nd), 'sha256': h, 'approved_census': census.get(n)}
    print(n, sum(e.values()), h[:12], census.get(n), flush=True)
json.dump(man, open(os.path.join(out, 'MANIFEST.json'), 'w'), indent=1)
