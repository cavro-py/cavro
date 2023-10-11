#!/bin/bash

set -xeuo pipefail

BUILD_DIR=build/docs

if [ ! -d $BUILD_DIR ]; then
    mkdir -p $BUILD_DIR
fi

DEST=doc/docs

CAVRO_VERSION=$(python -c 'import cavro; print(cavro.__version__)')

pdoc cavro -t doc/pdoc-templates --no-search -e cavro=https://github.com/stestagg/cavro/blob/v${CAVRO_VERSION}/ -o $BUILD_DIR

find doc/docs/ -name '*.ipynb' -exec jupyter nbconvert --to markdown {} --TagRemovePreprocessor.remove_cell_tags=hide \;


wget https://raw.githubusercontent.com/stestagg/cavro/perf/perf_results.json -O $BUILD_DIR/perf_results.json

PYTHONPATH=. python benchmark/update_docs.py $BUILD_DIR/perf_results.json

mv $BUILD_DIR/cavro.html $DEST/api.md

