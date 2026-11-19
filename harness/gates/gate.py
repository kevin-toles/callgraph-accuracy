"""gate.py BASELINE_DIR SCAN_DIR DISPOSITIONS.json [names...]

Diffs every scan in SCAN_DIR against the approved baseline (edge multisets keyed by
caller, callee, call_type, confidence, file, line) and groups the changes. An edge
removed and another added at the same file:line with the same caller is a CHANGE;
of what is left, an edge removed and one added at the same file:line with the same callee,
call_type and confidence but another caller is a CALLER rename; the rest are ADDED or REMOVED. Each group's signature is
  (language, kind, old confidence/call_type, new confidence/call_type, rule)
where rule is the disposition entry that claims it. A disposition entry is
  {"id": "...", "kind": "change|caller|added|removed|any", "language": "lua|*",
   "match": {"old_caller": regex, "new_caller": regex, "old_callee": regex, "new_callee": regex, "callee": regex, "caller": regex,
             "old": "conf/type", "new": "conf/type"},
   "disposition": "implementation defect fixed|ruling 2026-11-10 ...|...", "note": "..."}
or the built-in {"id": "...", "rule": "call_type", ...}, which claims exactly the edges whose
only change is a call_type relabel to what the direct-vs-method ruling gives.
Every changed edge must be claimed by an entry, or the gate fails and prints the
unclaimed groups with examples (GATE_DUMP=file also writes every unclaimed change as JSON). Exit 0 = every change dispositioned."""
import sys, os, re, json, collections
sys.path.insert(0, os.path.dirname(__file__))
from common import load_scan, edges, nodes, FANOUT
base, scans, dfile = sys.argv[1], sys.argv[2], sys.argv[3]
# GATE_MANIFEST names the manifest (repo languages) when BASELINE_DIR is an unfrozen scan dir.
man = json.load(open(os.environ.get('GATE_MANIFEST') or os.path.join(base, 'MANIFEST.json')))
names = sys.argv[4:] or sorted(n for n in man['repos'] if os.path.exists(os.path.join(scans, n + '.v2.json')))
disp = json.load(open(dfile)) if os.path.exists(dfile) else []
def ct(k): return f'{k[3]}/{k[2]}'
def call_type_rule(lang, k):
    # SPEC Decisions 2026-11-10, direct vs method (mirrors wire.normalizeCallTypes).
    callee, ctype, conf = k[1], k[2], k[3]
    if lang == 'lua' or ctype not in ('direct', 'method'):
        return ctype
    h = callee.rfind('#')
    if h >= 0:
        m = callee[h + 1:]
        if m == '<init>': return ctype
        if '.' not in m: return 'method'
        return 'direct' if conf != 'low' else ctype
    if conf != 'low' and not callee.startswith('.'): return 'direct'
    if conf == 'low': return 'method' if '.' in callee else 'direct'
    return ctype
def claims(d, lang, kind, old, new):
    if d.get('rule') == 'call_type':
        # A relabel only: same edge but call_type, and the new label is the ruling's.
        return (kind == 'change' and old[:2] == new[:2] and old[3:] == new[3:] and old[2] != new[2]
                and new[2] == call_type_rule(lang, new))
    if d.get('language', '*') not in ('*', lang): return False
    if d.get('kind', 'any') not in ('any', kind): return False
    m = d.get('match', {})
    def rx(key, val):
        return key not in m or (val is not None and re.search(m[key], val))
    oc = old[1] if old else None; nc = new[1] if new else None
    return (rx('old_caller', old[0] if old else None) and rx('new_caller', new[0] if new else None)
            and rx('old_callee', oc) and rx('new_callee', nc) and rx('callee', nc or oc)
            and rx('caller', (new or old)[0]) and rx('file', (new or old)[4])
            and ('old' not in m or (old and m['old'] == ct(old))) and ('new' not in m or (new and m['new'] == ct(new))))
unclaimed = collections.defaultdict(list); claimed = collections.Counter(); total = collections.Counter()
for n in names:
    lang = man['repos'][n]['language']
    a = edges(load_scan(os.path.join(base, n + '.v2.json')))
    b = edges(load_scan(os.path.join(scans, n + '.v2.json')))
    gone, new = a - b, b - a
    by = collections.defaultdict(list); left_o, left_n, changes = [], [], []
    for k, c in gone.items(): by[(k[4], k[5], k[0])] += [('-', k)] * c
    for k, c in new.items(): by[(k[4], k[5], k[0])] += [('+', k)] * c
    for site, items in by.items():
        olds = sorted(k for t, k in items if t == '-'); news = sorted(k for t, k in items if t == '+')
        # Pair edges with the same callee first, then the rest in order.
        pairs = []
        for o in list(olds):
            w = next((w for w in news if w[1] == o[1]), None)
            if w: pairs.append((o, w)); olds.remove(o); news.remove(w)
        pairs += list(zip(olds, news))
        n_paired = len(pairs) - len(list(zip(olds, news)))
        left_o += olds[len(pairs) - n_paired:]; left_n += news[len(pairs) - n_paired:]
        changes += [('change', o, w) for o, w in pairs]
    # A caller rename: an edge removed and one added at the same file:line with the
    # same callee, call_type and confidence, but a different caller.
    rest_n = collections.defaultdict(list)
    for k in left_n: rest_n[(k[4], k[5], k[1], k[2], k[3])].append(k)
    for k in left_o:
        same = rest_n.get((k[4], k[5], k[1], k[2], k[3]))
        if same: changes.append(('caller', k, same.pop()))
        else: changes.append(('removed', k, None))
    changes += [('added', None, k) for v in rest_n.values() for k in v]
    for kind, o, w in changes:
        total[n] += 1
        hit = next((d['id'] for d in disp if claims(d, lang, kind, o, w)), None)
        if hit: claimed[(n, hit)] += 1
        else:
            sig = (n, kind, ct(o) if o else '', ct(w) if w else '')
            unclaimed[sig].append((o, w))
print('repo changes:', dict(total))
for (n, i), c in sorted(claimed.items()): print(f'  claimed {n:32} {i:40} {c}')
for sig, ex in sorted(unclaimed.items(), key=lambda x: -len(x[1])):
    print(f'UNCLAIMED {sig} x{len(ex)}')
    for o, w in ex[:3]:
        print('    -', o[4].split('/')[-1] + ':' + str(o[5]), o[0], '->', o[1], ct(o)) if o else None
        print('    +', w[4].split('/')[-1] + ':' + str(w[5]), w[0], '->', w[1], ct(w)) if w else None
if os.environ.get('GATE_DUMP'):
    json.dump([[list(sig), [[list(o) if o else None, list(w) if w else None] for o, w in ex]] for sig, ex in unclaimed.items()], open(os.environ['GATE_DUMP'], 'w'))
sys.exit(1 if unclaimed else 0)
