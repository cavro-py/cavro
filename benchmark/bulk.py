import random
import os
from time import perf_counter

from benchmark.common import run_benchmark

import avro.datafile
import avro.io
import fastavro
import cavro

class Bulk:
    NAME = "bulk"
    BULK_FILE = os.path.join(os.path.dirname(__file__), 'pypi_downloads.avro')

    def avro(self):
        projects = set()
        left = 100
        with open(self.BULK_FILE, 'rb') as fh:
            reader = avro.datafile.DataFileReader(fh, avro.io.DatumReader())
            for record in reader:
                projects.add(record.get('file', {}).get('project'))
                left -= 1
                if not left:
                    break
        return projects

    def fastavro(self):
        projects = set()
        with open(self.BULK_FILE, 'rb') as fo:
            for record in fastavro.reader(fo):
                projects.add(record['file'].get('project'))
        return projects

    def cavro(self):
        projects = set()
        with open(self.BULK_FILE, 'rb') as fo:
            for record in cavro.Container(fo):
                projects.add(record.file.project)
        return projects
