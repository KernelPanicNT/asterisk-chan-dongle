#!/bin/bash
# Run a command under GitHub Actions and, if it fails, publish the tail of
# its output (and of config.log, if present) as error annotations so the
# failure is readable from the checks API/UI without downloading logs.
# Outside GitHub Actions it just runs the command.
#
# Usage: ci/gh-run.sh <title> <command> [args...]
set -uo pipefail

title=$1; shift
log=$(mktemp)

"$@" 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}

annotate() { # title file lines
    [ -f "$2" ] || return 0
    msg=$(tail -n "$3" "$2" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' | sed -e ':a;N;$!ba;s/\n/%0A/g')
    echo "::error title=$1::$msg"
}

if [ "$rc" -ne 0 ] && [ -n "${GITHUB_ACTIONS:-}" ]; then
    annotate "$title: output tail (exit $rc)" "$log" 80
    annotate "$title: config.log tail" config.log 60
fi
rm -f "$log"
exit "$rc"
