import glob
import os
import hashlib
from os import path
import re
import subprocess
import sys

from Cython.Build import cythonize
from setuptools import setup
from distutils.command.build_clib import build_clib
from setuptools.extension import Extension


PROJECT_ROOT = path.dirname(path.abspath(__file__))


with open(path.join(PROJECT_ROOT, "README.md")) as fh:
    LONG_DESCRIPTION = fh.read()


setup(
    name='cavro',
    ext_modules = cythonize(
        Extension(
            "cavro",
            sources=["cavro.pyx"],
            extra_compile_args=['-g', '-Wno-nullability-completeness','-Wno-unused-function', '-O2'], 
            extra_link_args=['-g'],
        ),
        compiler_directives={"language_level": 3, 'embedsignature': True},
    ),
    cmdclass = {'build_clib': build_clib},
    version='0.1',
    description="A Cython based Avro library",
    long_description=LONG_DESCRIPTION,
    author="Stephen Stagg",
    author_email="stestagg@gmail.com",
    python_requires=">=3.4.0",
    url="https://github.com/stestagg/cavro",
    license='MIT',
    classifiers=[
        # Trove classifiers
        # Full list: https://pypi.python.org/pypi?%3Aaction=list_classifiers
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: Implementation :: CPython',
    ],
)
