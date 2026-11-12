#!/bin/sh
# Bootstrap, configure, build and unit-test chan_dongle.
#
# Usage: ci/build-module.sh [extra ./configure args...]
#   ASTVERSION=24 ci/build-module.sh        -> force --with-astversion
#   WERROR=no     ci/build-module.sh        -> don't treat warnings as errors
set -eu

cd "$(dirname "$0")/.."

./bootstrap

set -- "$@"
[ -n "${ASTVERSION:-}" ] && set -- "$@" --with-astversion="$ASTVERSION"
[ "${WERROR:-yes}" = "yes" ] && set -- "$@" --enable-warnings-as-errors

./configure "$@"
make clean
make -k all
make check

echo "==> Built: $(pwd)/chan_dongle.so ($(cat VERSION))"
