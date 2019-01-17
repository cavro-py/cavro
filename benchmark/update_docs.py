import os
import json
import jinja2
from collections import defaultdict
import sys
from io import StringIO

import pygit2
import github
import matplotlib
matplotlib.use('SVG')
import matplotlib.pyplot as plt
plt.rcParams['svg.fonttype'] = 'none'
plt.rcParams['font.family'] = 'Verdana'
plt.rcParams['font.size'] = 8

from itertools import chain

from benchmark.main import ALL_TEST_CLASSES


def get_results():
    repo = pygit2.Repository('.')
    perf_refs = {}
    for ref in repo.references:
        if ref.startswith('refs/perf'):
            perf_data = repo.references[ref].get_object().data
            perf_refs[ref.rsplit('/', 1)[-1]] = json.loads(perf_data)
    sorted_results = []
    for commit in repo.walk(repo.head.target, pygit2.GIT_SORT_TOPOLOGICAL):
        commit_hash = commit.id.hex
        result = {}
        if commit_hash in perf_refs:
            result = perf_refs[commit_hash]
        sorted_results.append((commit, result))
    return sorted_results

def format_results(results):
    all_tests = set(chain(*[r.keys() for c, r in results]))
    all_tests -= {'now', 'bulk'} # doh
    formatted = {t: [] for t in all_tests}
    for commit, result in results:
        for test in all_tests:
            formatted[test].append({
                'run_time': result.get('now'),
                'commit_time': commit.commit_time,
                'commit': commit.hex,
                'results': result.get(test, {})
            })
    return formatted

def make_commit_graph(results):
    plt.figure(figsize=[10, 5])
    results = reversed(results)
    results = [r for r in results if r['results']]
    all_libs = sorted(set(chain(*(r['results'].keys() for r in results))))
    lib_times = defaultdict(list)
    hashes = []
    max_val = 0
    for result in results:
        hashes.append(result['commit'][:5])
        for lib in all_libs:
            val = result['results'].get(lib, {}).get('min')
            lib_times[lib].append(val)
            max_val = max(max_val, val)

    axes = plt.axes()
    for lib in all_libs:
        times = lib_times[lib]
        plt.step(hashes, times, label=lib, where='mid')
        axes.annotate(
            f'{lib} = {times[-1]:.2f} s',
            (len(hashes)-1, times[-1]),
            xytext=(-6, 6),
            horizontalalignment='right',
            textcoords='offset points',
            bbox={
                'boxstyle':'round,pad=0.2',
                'fc': '#f0f0f0',
                'ec': '#c0c0c0',
                'lw': 0.5,
                'alpha': 0.3,

            }
        )
    plt.legend(loc=3, borderpad=1, labelspacing=1)
    plt.margins(0.01,0)
    plt.title("Benchmark results by commit (lower is better)")
    axes.set_ylim(0, max_val * 1.04)
    axes.set_facecolor('#fefefe')
    axes.set_xlabel('Commit')
    axes.set_ylabel('Wallclock time (s)')
    axes.grid(True, linewidth=0.5, color="#dddddd")
    plt.tight_layout()
    buf = StringIO()
    plt.savefig(buf, format='svg')
    return buf.getvalue()

def save_docs(html):
    print('Writing benchmark.html')
    with open("benchmark.html", "w") as fh:
        fh.write(html)


def upload_docs(html):
    print("Uploading html")
    g = github.Github(os.environ['GITHUB_TOKEN'])
    g.FIX_REPO_GET_GIT_REF = False
    gh_repo = g.get_user('stestagg').get_repo('cavro')

    current_file = gh_repo.get_contents('benchmark.html', ref='gh-pages')
    gh_repo.update_file(
        current_file.path,
        'Automated upload of benchmark results',
        html,
        current_file.sha,
        branch='docs'
    )

def render_docs(results):
    template_path = os.path.join(os.path.dirname(__file__), 'templates')
    loader = jinja2.FileSystemLoader(template_path)
    env = jinja2.Environment(loader=loader)
    template = env.get_template('benchmark.html')
    return template.render(
        results=results,
        classes={c.NAME: c for c in ALL_TEST_CLASSES},
        make_commit_graph=make_commit_graph,
    )


def main():
    results = get_results()
    formatted = format_results(results)
    html = render_docs(formatted)

    if 'GITHUB_TOKEN' in os.environ:
        upload_docs(html)
    else:
        save_docs(html)

if __name__ == '__main__':
    sys.exit(main())