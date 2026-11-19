"""python3 gates/test_pool.py — pool.py applies adjudicated review figures.

A ruling in FANOUT/ADJUDICATIONS.json replaces the reviewer's census only for the
report it was made on; ACCURACY.md marks the row and keeps the raw figure."""
import json, os, subprocess, sys, tempfile, unittest

POOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'pool.py')

def report(census, wrong, judged):
    return f'# r\n\nSummary: census {census}% ({wrong} wrong of {judged}). precision 49/50; 0 missed of 10\n'

class PoolAdjudication(unittest.TestCase):
    def run_pool(self, adjudications):
        d = tempfile.mkdtemp()
        json.dump([['s-a', 'ts', ''], ['s-b', 'ts', '']], open(f'{d}/repos.json', 'w'))
        # s-a: latest report v2 is raw 97.84% (31/1434), ruled 27/1434.
        open(f'{d}/s-a_report.v1.md', 'w').write(report('98.19', 26, 1434))
        open(f'{d}/s-a_report.v2.md', 'w').write(report('97.84', 31, 1434))
        # s-b: a ruling on the older v1 must not touch the latest v2.
        open(f'{d}/s-b_report.v1.md', 'w').write(report('97.00', 30, 1000))
        open(f'{d}/s-b_report.v2.md', 'w').write(report('99.00', 10, 1000))
        if adjudications is not None:
            json.dump(adjudications, open(f'{d}/ADJUDICATIONS.json', 'w'))
        subprocess.run([sys.executable, POOL, d], check=True, capture_output=True)
        return json.load(open(f'{d}/ACCURACY.json')), open(f'{d}/ACCURACY.md').read()

    def test_ruling_on_latest_report_replaces_census(self):
        acc, md = self.run_pool({
            's-a_report.v2.md': {'wrong': 27, 'judged': 1434, 'ruling': 'adjudications.md: s-a'},
            's-b_report.v1.md': {'wrong': 5, 'judged': 1000, 'ruling': 'adjudications.md: s-b'}})
        ts = acc['languages']['ts']
        self.assertEqual(ts['repo_precision']['s-a'], round(1 - 27 / 1434, 4))
        self.assertEqual(ts['repo_precision']['s-b'], 0.99)
        self.assertEqual(ts['wrong_edges'], 27 + 10)
        self.assertTrue(ts['meets_target'])
        self.assertEqual(ts['adjudicated'], {'s-a': {'report': 's-a_report.v2.md', 'raw_wrong': 31,
                                                      'wrong': 27, 'judged': 1434, 'ruling': 'adjudications.md: s-a'}})
        self.assertIn('s-a 98.1% adjudicated (raw 97.8%)', md)

    def test_no_adjudications_file_keeps_raw(self):
        acc, md = self.run_pool(None)
        ts = acc['languages']['ts']
        self.assertEqual(ts['repo_precision']['s-a'], round(1 - 31 / 1434, 4))
        self.assertFalse(ts['meets_target'])
        self.assertEqual(ts['adjudicated'], {})
        self.assertNotIn('adjudicated', md)

    def test_ruling_must_cover_same_judged_edges(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_pool({'s-a_report.v2.md': {'wrong': 27, 'judged': 1400, 'ruling': 'x'}})

if __name__ == '__main__':
    unittest.main()
