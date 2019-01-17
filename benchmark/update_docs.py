import os
import json
import sys

import pygit2
import github
from itertools import chain


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
    all_tests -= {'now'} # doh
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


def save_formatted(results):
    print('Writing benchmarks to benchmark.json')
    with open("benchmark.json", "w") as fh:
        fh.write(json.dumps(results, indent=2))


def upload_formatted(results):
    print("Uploading formatted results")
    results_blob = json.dumps(results)
    g = github.Github(os.environ['GITHUB_TOKEN'])
    g.FIX_REPO_GET_GIT_REF = False
    gh_repo = g.get_user('stestagg').get_repo('cavro')

    current_file = gh_repo.get_contents('benchmark_results.json', ref='docs')
    gh_repo.update_file(
        current_file.path,
        'Automated upload of benchmark results',
        results_blob,
        current_file.sha,
        branch='docs'
    )


def main():
    results = get_results()
    formatted = format_results(results)
    if 'GITHUB_TOKEN' in os.environ:
        upload_formatted(formatted)
    else:
        save_formatted(formatted)

if __name__ == '__main__':
    sys.exit(main())