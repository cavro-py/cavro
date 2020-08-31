import random
import os
from time import perf_counter

import avro.datafile
import avro.io
import fastavro
import cavro

class PypiFile:

    """
    Measure the time taken to read all records from one file (11 Mb) of pypi
    download logs, sourced from google bigquery public dataset
    """

    NUM_RUNS = 3
    NAME = "pypi_file"

    BULK_FILE = os.path.join(os.path.dirname(__file__), 'pypi_downloads.avro')

    def avro(self):
        projects = set()
        with open(self.BULK_FILE, 'rb') as fh:
            reader = avro.datafile.DataFileReader(fh, avro.io.DatumReader())
            for record in reader:
                projects.add(record.get('file', {}).get('project'))
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
            for record in cavro.ContainerReader(fo):
                projects.add(record.file.project)
        return projects
