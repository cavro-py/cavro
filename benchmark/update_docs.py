from pathlib import Path
import textwrap
import json
import os
import sys
from itertools import chain

import click
import jinja2
import numpy as np
import pandas as pd

from benchmark.main import ALL_TEST_CLASSES


def get_results(path):
    results = json.loads(path.read_text())
    results = sorted(results, key=lambda r: r.get('now', 0))
    return results


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


def results_table(results, test):
    r2 = results.query('test == @test')
    last_hash = r2.iloc[-1]['short_hash']
    r2 = r2.query('short_hash == @last_hash').sort_values('lib').set_index('lib')
    if 'avro' in r2.index:
        avro_time = r2.loc['avro', 'min']
        r2['normalized'] = r2['min'] / avro_time

    r2 = r2[['min', 'normalized', 'timings']]
    
    r2['timings'] = r2['timings'].map(lambda v: ', '.join([f'{t:.4f}' for t in v]))
    r2['min'] = r2['min'].map(lambda v: f'{v:.4f}')    
    r2['normalized'] = r2['normalized'].map(lambda v: f'{v:.4f}')
    r2 = r2.rename({'min': 'min (s)', 'normalized': 'normalized (avro=1)', 'timings': 'timings (s)'}, axis=1)
    return r2.to_markdown()#float_format='%.2f', formatters={'timings (s)': lambda v: ', '.join([f'{t:.4f}' for t in v])})


def line_data(results, test):
    r2 = results.query('test == @test')
    libs = sorted(r2['lib'].unique())
    hashes = pd.Series(r2['short_hash'].unique()).values[-50:]
    r2 = r2.set_index('short_hash')
    
    datasets = [
        {
            'label': lib,
            'data': list(r2.query('lib == @lib').reindex(hashes)['min'].values),
            'stepped': 'middle',
        }
        for lib in libs
    ]

    content = json.dumps({
        'labels': list(hashes),
        'datasets': datasets
    })
    return '{' + content + '}'


def save_docs(md, out_file):
    print(f'Writing {out_file}')
    with open(out_file, "w") as fh:
        fh.write(md)

def render_docs(results):
    tests = sorted(results['test'].unique())
    test_classes = {t.NAME: t for t in ALL_TEST_CLASSES if t.NAME in tests}
    libs = sorted(results['lib'].unique())

    latest_result = results.iloc[-1].to_dict()

    template_path = os.path.join(os.path.dirname(__file__), 'templates')
    loader = jinja2.FileSystemLoader(template_path)
    env = jinja2.Environment(loader=loader)
    template = env.get_template('benchmark.md')
    return template.render(
        results=results,
        tests=tests,
        libs=libs,
        classes=test_classes,
        dedent=textwrap.dedent,
        line_data=line_data,
        results_table=results_table,
        latest_result=latest_result
    )

def make_results_table(results):
    table = pd.DataFrame(results)
    by_test = (pd.DataFrame(list(table['results']))
        .melt([], var_name='test', ignore_index=False)
        .merge(table.drop(columns=['results']), left_index=True, right_index=True)
        .dropna(subset=['value'])
        .reset_index(drop=True)
    )
    by_lib = (pd.DataFrame(list(by_test['value']))
        .melt([], var_name='lib', ignore_index=False)
        .merge(by_test.drop(columns=['value']), left_index=True, right_index=True)
        .dropna(subset=['value', 'test', 'now'])
        .rename({'value': 'timings'}, axis=1)
        .drop(columns=['previous'])
        .sort_values('now')
        .reset_index(drop=True)
    )
    by_lib['min'] = by_lib['timings'].map(min)
    unique_hashes = by_lib['hash'].value_counts().index

    hash_len = 4
    while True:
        short_hashes = unique_hashes.str[:hash_len]
        if len(short_hashes.unique()) == len(short_hashes):
            break
        hash_len += 1
    by_lib['short_hash'] = by_lib['hash'].str[:hash_len]
    by_lib['date'] = pd.to_datetime(by_lib['now'], unit='s')
    return by_lib
    

@click.command()
@click.argument('results_file', type=click.Path(dir_okay=False, readable=True, path_type=Path))
@click.argument('out_file', type=click.Path(dir_okay=False, writable=True, path_type=Path))
def main(results_file, out_file):
    results = get_results(results_file)
    results_table = make_results_table(results)
    html = render_docs(results_table)
    save_docs(html, out_file)

if __name__ == '__main__':
    main()