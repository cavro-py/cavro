import glob
import os
import hashlib
from os import path
import re
import subprocess
import sys

from setuptools import setup
from distutils.command.build_clib import build_clib
from setuptools.extension import Extension


PROJECT_ROOT = path.dirname(path.abspath(__file__))


with open(path.join(PROJECT_ROOT, "README.md")) as fh:
    LONG_DESCRIPTION = fh.read()


sources = ['cavro.c']
ext_args = {
    'extra_compile_args': ['-g', '-O2'], 
    'extra_link_args': ['-g'],
}

try:
    from Cython.Build import cythonize
except ImportError:
    ext = Extension('cavro', sources=['cavro.c'], **ext_args)
else:
    ext = cythonize(
        Extension('cavro', sources=['cavro.pyx'], **ext_args),
        compiler_directives={"language_level": 3},
    )


setup(
    name='cavro',
    ext_modules = cythonize(
        Extension(
            "cavro",
            sources=["cavro.pyx"],
            
        ),
        compiler_directives={"language_level": 3},
    ),
    cmdclass = {'build_clib': build_clib},
    version='1.0.0',
    description="A Cython based Avro library",
    long_description=LONG_DESCRIPTION,
    author="Stephen Stagg",
    author_email="stestagg@gmail.com",
    python_requires=">=3.8.0",
    url="https://cavro.io/",
    license='MIT',
    classifiers=[
        # Trove classifiers
        # Full list: https://pypi.python.org/pypi?%3Aaction=list_classifiers
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Cython',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Programming Language :: Python :: 3.12',
        'Programming Language :: Python :: 3.13',
        'Programming Language :: Python :: Implementation :: CPython',
    ],
)
