#!/bin/bash

set -xeuo pipefail

NEW_VERSION=$1

echo "Updating version to $NEW_VERSION"

echo "Updating setup.py"
sed -i '' "s/version='.*',/version='"$NEW_VERSION"',/g" setup.py

echo "Updating pyproject.toml"
sed -i '' "s/version = \".*\"/version = \"$NEW_VERSION\"/g" pyproject.toml

echo "Updating cavro.pyx"
sed -i '' "s/__version__ = \".*\"/__version__ = \"$NEW_VERSION\"/g" cavro.pyx