import json, os, re, sys, collections
# pool.py FANOUT — per-language accuracy from the blind reviews of untouched
# repos (h-* holdouts, s-* samples), pooled edge-weighted; development repos
# (their latest report) listed separately. Writes FANOUT/ACCURACY.md.
F = sys.argv[1]
R = json.load(open(f'{F}/repos.json'))
# Review reports live in F/reviews when that folder exists (this repository's layout), else in F.
RV = f'{F}/reviews' if os.path.isdir(f'{F}/reviews') else F
summ = re.compile(r'census\s*[≈~]?\s*([\d.]+)%\s*\((\d[\d,]*)\s*wrong of\s*(\d[\d,]*)', re.I)
prec = re.compile(r'precision\D{0,20}?(\d+)\s*/\s*(\d+)', re.I)
rec = re.compile(r'(\d+)\s+missed\s+of\s+(\d+)', re.I)
def latest(name):
    # The highest-versioned report (name_report.vN.md), else name_report.md.
    best = None
    for p in os.listdir(RV):
        m = re.fullmatch(re.escape(name) + r'_report(?:\.v(\d+))?\.md', p)
        if m and (best is None or int(m.group(1) or 1) > best[0]):
            best = (int(m.group(1) or 1), f'{RV}/{p}')
    return best and best[1]
# Adjudicated figures (FANOUT/ADJUDICATIONS.json, rulings in FANOUT/adjudications.md):
# {report file: {wrong, judged, ruling}}. A ruling replaces the reviewer's wrong count
# only when its report is the one pooled; it must cover the same judged edges.
ADJ = json.load(open(f'{F}/ADJUDICATIONS.json')) if os.path.exists(f'{F}/ADJUDICATIONS.json') else {}
pool = collections.defaultdict(lambda: {'W': 0, 'E': 0, 'repos': [], 'pending': [], 'adj': {}})
dev = []
for name, lang, rel in R:
    rep = latest(name)
    untouched = name.startswith(('h-', 's-'))
    if rep is None:
        if untouched:
            pool[lang]['pending'].append(name)
        continue
    body = open(rep).read().split('## Previous findings')[0]
    m = summ.search(body)
    p, r = prec.search(body), rec.search(body)
    a = ADJ.get(os.path.basename(rep))
    raw = None
    if m:
        w, e = int(m.group(2).replace(',', '')), int(m.group(3).replace(',', ''))
        if a:
            if a['judged'] != e:
                sys.exit(f"ADJUDICATIONS.json {os.path.basename(rep)}: judged {a['judged']} != report's {e}")
            raw = (w, 100 * (1 - w / e))
            pool[lang]['adj'][name] = {'report': os.path.basename(rep), 'raw_wrong': w, 'wrong': a['wrong'],
                                       'judged': e, 'ruling': a['ruling']}
            w = a['wrong']
    row = (name, os.path.basename(rep), f'{p.group(1)}/{p.group(2)}' if p else '?',
           f'{r.group(1)} of {r.group(2)}' if r else '?',
           (100 * (1 - w / e) if raw else float(m.group(1))) if m else None, raw)
    if untouched:
        if m:
            pool[lang]['W'] += w
            pool[lang]['E'] += e
            # Each repo's own precision: the target holds per repo.
            pool[lang].setdefault('per', {})[name] = 1 - w / e if e else None
        pool[lang]['repos'].append(row)
    else:
        dev.append((lang,) + row)
TARGET = 0.98
def worst(d):
    per = {n: p for n, p in d.get('per', {}).items() if p is not None}
    return min(per.items(), key=lambda kv: kv[1]) if per else (None, None)
out = ['# Call-graph accuracy by language', '',
       f'Untouched repos (holdout + random sample). The target is per repo: every reviewed repo at {TARGET:.0%} or above, so the worst repo is the figure that counts. The pooled census (edge-weighted, dominated by large repos) is shown alongside.', '',
       '| language | worst repo | meets per-repo target | pooled census | repos reviewed | per-repo census (sample) | pending |', '|---|---|---|---|---|---|---|']
for lang in sorted(set(l for _, l, _ in R)):
    d = pool[lang]
    pc = f"{100*(1-d['W']/d['E']):.2f}% ({d['W']} of {d['E']})" if d['E'] else '–'
    wn, wp = worst(d)
    wc = f"{wn} {100*wp:.2f}%" if wn else '–'
    ok = ('yes' if wp >= TARGET else '**no**') if wn else '–'
    per = '; '.join((f"{n} {c:.1f}% adjudicated (raw {raw[1]:.1f}%) ({s})" if raw else f"{n} {c:.1f}% ({s})") if c is not None else f"{n} ? ({s})" for n, _, s, _, c, raw in d['repos'])
    out.append(f"| {lang} | {wc} | {ok} | {pc} | {len(d['repos'])} | {per} | {' '.join(d['pending'])} |")
out += ['', '## Development repos (fixes were tuned on these)', '', '| language | repo | report | sample | recall | census |', '|---|---|---|---|---|---|']
for lang, n, rp, s, r, c, _ in sorted(dev):
    out.append(f"| {lang} | {n} | {rp} | {s} | {r} | {f'{c:.1f}%' if c is not None else '?'} |")
open(f'{F}/ACCURACY.md', 'w').write('\n'.join(out) + '\n')
# Machine-readable copy for the service (internal/usecases/measured_accuracy.json):
# census pooled per language over the untouched repos, with the curated known
# gaps (KNOWN_GAPS.json) and notes on builder changes since the measurement.
import datetime
gaps = json.load(open(f'{F}/KNOWN_GAPS.json')) if os.path.exists(f'{F}/KNOWN_GAPS.json') else {}
langs = {}
for lang in sorted(set(l for _, l, _ in R)):
    d = pool[lang]
    if not d['E']:
        continue
    g = gaps.get(lang, {})
    wn, wp = worst(d)
    langs[lang] = {'census_precision': round(1 - d['W'] / d['E'], 4), 'wrong_edges': d['W'], 'judged_edges': d['E'],
                   'repo_precision': {n: round(p, 4) for n, p in d.get('per', {}).items() if p is not None},
                   'worst_repo': wn, 'worst_repo_precision': round(wp, 4), 'target_precision': TARGET, 'meets_target': wp >= TARGET,
                   'repos': [n for n, _, _, _, c, _ in d['repos'] if c is not None], 'adjudicated': d['adj'], 'known_gaps': g.get('gaps', []), 'note': g.get('note', '')}
json.dump({'measured_on': os.environ.get('MEASURED_ON', datetime.date.today().isoformat()),
           'method': 'blind review of untouched repos (holdout + random sample): every in-scope edge judged by scripted census of wrong patterns, validated by hand; per-repo precision, the target met when the worst repo reaches it; pooled edge-weighted per language alongside',
           'languages': langs}, open(f'{F}/ACCURACY.json', 'w'), indent=1)
print('\n'.join(out[:30]))
