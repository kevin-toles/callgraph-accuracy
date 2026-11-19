import json, gzip, collections, os
def load_scan(p):
    if not os.path.exists(p) and os.path.exists(p + '.gz'):
        p = p + '.gz'
    with (gzip.open(p, 'rt') if p.endswith('.gz') else open(p)) as f:
        return json.load(f)
def edge_key(e):
    return (e['caller_id'], e['callee_id'], e['call_type'], e['confidence'], e['source_file'], e['line_number'])
def edges(scan):
    return collections.Counter(edge_key(e) for e in scan['call_graph']['edges'])
def nodes(scan):
    return set(scan['call_graph'].get('nodes') or [])
def repos(fanout):
    return {n: (l, r) for n, l, r in json.load(open(os.path.join(fanout, 'repos.json')))}
FANOUT = os.environ.get('CALLGRAPH_FANOUT', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'results'))
