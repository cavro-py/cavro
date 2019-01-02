import random
from time import perf_counter

from benchmark.common import time_it, compare

import avro.datafile
import avro.io
import fastavro
import cavro

NUM_RECORDS = 10_000_000
BULK_FILE = 'data/avro000000000000'


@time_it
def bulk_avro():
    projects = set()
    reader = avro.datafile.DataFileReader(open(BULK_FILE, 'rb'), avro.io.DatumReader())
    for record in reader:
        projects.add(record.get('file', {}).get('project'))
    return projects


@time_it
def bulk_fastavro():
    projects = set()
    with open(BULK_FILE, 'rb') as fo:
        for record in fastavro.reader(fo):
            projects.add(record['file'].get('project'))
    return projects


@time_it
def bulk_cavro():
    projects = set()
    with open(BULK_FILE, 'rb') as fo:
        for record in cavro.Container(fo):
            projects.add(record.file.project)
    return projects


def main():
    compare('bulk', bulk_avro, bulk_cavro, bulk_fastavro)


if __name__ == '__main__':
    main()