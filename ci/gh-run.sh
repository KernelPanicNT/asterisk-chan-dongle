#!/bin/bash
# Run a command under GitHub Actions and, if it fails, publish the failing
# lines and the tail of its output (and of config.log, if present) as error
# annotations, readable from the checks API/UI without downloading logs.
# Outside GitHub Actions it just runs the command.
#
# Usage: ci/gh-run.sh <title> <command> [args...]
set -uo pipefail

title=$1; shift
log=$(mktemp)

"$@" 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}

annotate() { # title file lines
    [ -s "$2" ] || return 0
    # annotations are cut at ~4 KB: keep lines short
    msg=$(tail -n "$3" "$2" | cut -c1-200 | sed -e 's/%/%25/g' -e 's/\r/%0D/g' | sed -e ':a;N;$!ba;s/\n/%0A/g')
    echo "::error title=$1::$msg"
}

if [ "$rc" -ne 0 ] && [ -n "${GITHUB_ACTIONS:-}" ]; then
    # failing checks first (test FAIL lines with 2 lines of context,
    # compiler errors, make errors, crashes)
    grep -E -B2 '(FAIL|FAILS)$|unsuccessful|: (fatal )?error:|Error [0-9]+$|Segmentation fault|Aborted' "$log" \
        | grep -vE '^(gcc|cc) ' | head -n 40 >"$log.fail" || true
    annotate "$title: failures (exit $rc)" "$log.fail" 40
    rm -f "$log.fail"
    annotate "$title: output tail (exit $rc)" "$log" 40
    annotate "$title: config.log tail" config.log 30
fi
rm -f "$log"
exit "$rc"
