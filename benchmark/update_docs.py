import base64
import textwrap
import json
import operator
import os
import sys
from collections import defaultdict
from datetime import datetime
from functools import reduce
from io import StringIO
from itertools import chain

import github
import jinja2
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import plotly.io
import pygit2

from benchmark.main import ALL_TEST_CLASSES


def get_results():
    repo = pygit2.Repository('.')
    perf_refs = {}
    print('Finding refs:')
    for ref in repo.references:
        print(ref)
        if ref.startswith('refs/perf'):
            blob_id = repo.references[ref].target
            perf_data = repo.get(blob_id).data
            perf_refs[ref.rsplit('/', 1)[-1]] = json.loads(perf_data)
    sorted_results = []
    for commit in repo.walk(repo.head.target, pygit2.GIT_SORT_TOPOLOGICAL):
        commit_hash = commit.id.hex
        result = {}
        if commit_hash in perf_refs:
            result = perf_refs[commit_hash]
        sorted_results.append((commit, result))
    return repo.head.target.hex, sorted_results


def format_results(results):
    all_tests = set(chain(*[r.keys() for c, r in results]))
    all_tests -= {'now', 'bulk', 'previous'} # doh
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


def convert_item(item):
    new_items = []
    base = {k: v for k, v in item.items() if k != 'results'}
    res = item.get('results', {})
    for lib, data in res.items():
        lib_base = base.copy()
        lib_base['lib'] = lib
        lib_base.update(data)
        new_items.append(lib_base)
    return new_items

def results_table(results, commit):
    results = reversed(results)
    results = [r for r in results if r['results']]
    converted = [c for r in results for c in convert_item(r)]
    r2 = pd.DataFrame(converted)
    last_run = r2['run_time'].max()
    r2 = r2.query('run_time == @last_run')
    r2 = r2.drop(columns=['run_time', 'commit_time', 'commit']).set_index('lib')
    r2['timings'] = r2['timings'].map(lambda v: ', '.join([f'{t:.4f}' for t in v]))
    r2['min'] = r2['min'].map(lambda v: f'{v:.4f}')
    r2['std'] = r2['std'].map(lambda v: f'{v:.4f}')
    r2['normalized'] = r2['normalized'].map(lambda v: f'{v:.4f}')
    r2 = r2.rename({'min': 'min (s)', 'std': 'std (s)', 'normalized': 'normalized (avro=1)', 'timings': 'timings (s)'}, axis=1)
    return r2.to_markdown()#float_format='%.2f', formatters={'timings (s)': lambda v: ', '.join([f'{t:.4f}' for t in v])})


def line_data(results):
    results = reversed(results)
    results = [r for r in results if r['results']][-50:]
    converted = [c for r in results for c in convert_item(r)]
    r2 = pd.DataFrame(converted)
    libs = sorted(r2['lib'].unique())
    hashes = pd.Series(r2.sort_values('commit_time')['commit'].unique())
    hash_len = 4
    while True:
        short_hash = hashes.str[:hash_len]
        if len(short_hash.unique()) == len(short_hash):
            break
        hash_len += 1
    short_hash.index = hashes.values
    r2['commit_short'] = r2['commit'].map(short_hash)
    r2 = r2.set_index('commit_short')

    datasets = [
        {
            'label': lib,
            'data': list(r2.query('lib == @lib').reindex(short_hash.values)['min'].values),
            'stepped': 'middle',
        }
        for lib in libs
    ]

    content = json.dumps({
        'labels': list(short_hash.values),
        #'times': [int(v) for v in r2['commit_time'].values],
        'datasets': datasets
    })
    return '{' + content + '}'


def save_docs(md):
    print('Writing benchmark.html')
    with open("doc/docs/benchmarks.md", "w") as fh:
        fh.write(md)


# def upload_docs(html):
#     print("Uploading html")
#     g = github.Github(os.environ['UPLOAD_TOKEN'])
#     g.FIX_REPO_GET_GIT_REF = False
#     gh_repo = g.get_user('stestagg').get_repo('cavro')

#     current_file = gh_repo.get_contents('benchmark.html', ref='gh-pages')
#     gh_repo.update_file(
#         current_file.path,
#         'Automated upload of benchmark results',
#         html,
#         current_file.sha,
#         branch='gh-pages'
#     )
#     gh_repo._requester.requestJsonAndCheck(
#         'POST',
#         gh_repo.url+'/pages/builds',
#         headers={
#             'Accept': 'application/vnd.github.mister-fantastic-preview+json'
#         }
#     )

def render_docs(results, latest_commit):
    template_path = os.path.join(os.path.dirname(__file__), 'templates')
    loader = jinja2.FileSystemLoader(template_path)
    env = jinja2.Environment(loader=loader)
    template = env.get_template('benchmark.md')
    return template.render(
        results=results,
        classes={c.NAME: c for c in ALL_TEST_CLASSES},
        dedent=textwrap.dedent,
        line_data=line_data,
        results_table=results_table,
        latest_commit=latest_commit
    )


def main():
    latest_commit, results = get_results()
    formatted = format_results(results)
    html = render_docs(formatted, latest_commit)
    save_docs(html)
    # if 'UPLOAD_TOKEN' in os.environ:
    #     upload_docs(html)

if __name__ == '__main__':
    sys.exit(main())