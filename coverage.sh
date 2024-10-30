#!/bin/bash

# generates lcov.info
forge coverage --via-ir \
    --report lcov

if ! command -v lcov &>/dev/null; then
    echo "lcov is not installed. Installing..."
    sudo apt-get install lcov
fi

lcov --version

EXCLUDE="*test* *mocks* *node_modules* *script* *src/executors/example*"
lcov \
    --rc branch_coverage=1 \
    --remove lcov.info $EXCLUDE \
    --output-file forge-pruned-lcov.info \
    --ignore-errors inconsistent

if [ "$CI" != "true" ]; then
    genhtml forge-pruned-lcov.info \
        --rc branch_coverage=1 \
        --output-directory coverage \
        --ignore-errors inconsistent
    open coverage/index.html
fi
