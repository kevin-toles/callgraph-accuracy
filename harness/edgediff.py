import json, sys, collections
# edgediff.py BASELINE NEW [N] — edges in one scan and not the other, as
# (caller, callee, call_type, confidence, file, line) multisets.
def load(p):
    es = json.load(open(p))['call_graph']['edges']
    return collections.Counter((e['caller_id'], e['callee_id'], e['call_type'], e['confidence'], e['source_file'], e['line_number']) for e in es)
a, b = load(sys.argv[1]), load(sys.argv[2])
gone, new = a - b, b - a
n = int(sys.argv[3]) if len(sys.argv) > 3 else 0
print(f"removed {sum(gone.values())} added {sum(new.values())}")
for tag, c in (('-', gone), ('+', new)):
    for k in sorted(c)[:n]:
        print(tag, k[4].split('/')[-1] + ':' + str(k[5]), k[0], '->', k[1], k[2], k[3])
