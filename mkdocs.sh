#!/bin/bash

set -xeuo pipefail

BUILD_DIR=dest/docs

if [ ! -d $BUILD_DIR ]; then
    mkdir -p $BUILD_DIR
fi

DEST=doc/docs

CAVRO_VERSION=$(python -c 'import cavro; print(cavro.__version__)')

pdoc cavro -t doc/pdoc-templates --no-search -e cavro=https://github.com/stestagg/cavro/blob/v${CAVRO_VERSION}/ -o $BUILD_DIR

find doc/docs/ -name '*.ipynb' -exec jupyter nbconvert --to markdown {} --TagRemovePreprocessor.remove_cell_tags=hide \;

mv $BUILD_DIR/cavro.html $DEST/api.md