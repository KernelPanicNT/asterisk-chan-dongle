#!/bin/sh
# Runtime smoke test: start an *isolated* Asterisk instance (own config, run,
# log and spool dirs under a temp dir) that loads only chan_dongle.so, and
# check that the module, channel type, CLI, dialplan apps and AMI actions
# are registered and that the module unloads/reloads cleanly.
#
# It never touches /etc/asterisk or a running Asterisk/FreePBX instance, so
# it is safe to run on a production-like box. No modem is required.
#
# Usage: ci/smoke-test.sh [path/to/chan_dongle.so]
#   ASTERISK=/usr/sbin/asterisk  ASTMODDIR=/usr/lib/asterisk/modules
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
MOD=$(readlink -f "${1:-$SRC/chan_dongle.so}")
AST=${ASTERISK:-$(command -v asterisk || echo /usr/sbin/asterisk)}
VERSION=$(cat "$SRC/VERSION")

[ -f "$MOD" ] || { echo "module not found: $MOD" >&2; exit 2; }

if [ -z "${ASTMODDIR:-}" ]; then
    for d in /usr/lib/asterisk/modules /usr/lib64/asterisk/modules \
             /usr/lib/x86_64-linux-gnu/asterisk/modules \
             /usr/lib/aarch64-linux-gnu/asterisk/modules \
             /lib/x86_64-linux-gnu/asterisk/modules \
             /usr/local/lib/asterisk/modules; do
        [ -f "$d/pbx_config.so" ] && { ASTMODDIR=$d; break; }
    done
fi
[ -n "${ASTMODDIR:-}" ] || { echo "cannot find asterisk modules dir" >&2; exit 2; }

T=$(mktemp -d /tmp/chan_dongle-smoke.XXXXXX)
mkdir -p "$T/etc" "$T/mod" "$T/run" "$T/log" "$T/spool" "$T/lib" "$T/data" "$T/key"
for f in "$ASTMODDIR"/*.so; do ln -s "$f" "$T/mod/"; done
ln -sf "$MOD" "$T/mod/chan_dongle.so"

cat >"$T/etc/asterisk.conf" <<EOF
[directories]
astetcdir => $T/etc
astmoddir => $T/mod
astvarlibdir => $T/lib
astdbdir => $T/lib
astkeydir => $T/key
astdatadir => $T/data
astagidir => $T/data/agi-bin
astspooldir => $T/spool
astrundir => $T/run
astlogdir => $T/log
[options]
verbose = 3
EOF
cat >"$T/etc/modules.conf" <<EOF
[modules]
autoload = no
load => chan_dongle.so
EOF
cat >"$T/etc/logger.conf" <<EOF
[logfiles]
messages.log => notice,warning,error
EOF
cat >"$T/etc/manager.conf" <<EOF
[general]
enabled = no
EOF
sed -e "s|^smsdb=.*|smsdb=$T/lib/smsdb|" "$SRC/etc/dongle.conf" >"$T/etc/dongle.conf"

rx() { "$AST" -C "$T/etc/asterisk.conf" -rx "$1" 2>&1; }

cleanup() {
    rx "core stop now" >/dev/null 2>&1 || true
    sleep 1
    [ -n "${PID:-}" ] && kill "$PID" 2>/dev/null || true
    if [ "${KEEP:-no}" = "yes" ]; then echo "kept: $T"; else rm -rf "$T"; fi
}
trap cleanup EXIT INT TERM

"$AST" -C "$T/etc/asterisk.conf" -f -n -q >"$T/log/console.log" 2>&1 &
PID=$!

i=0
until rx "core waitfullybooted" | grep -q "fully booted"; do
    i=$((i + 1))
    if [ $i -gt 60 ] || ! kill -0 "$PID" 2>/dev/null; then
        echo "asterisk did not boot" >&2
        cat "$T/log/console.log" "$T/log/messages.log" 2>/dev/null >&2 || true
        exit 1
    fi
    sleep 1
done

FAIL=0
check() { # description, command, expected-regex
    out=$(rx "$2")
    if echo "$out" | grep -qE "$3"; then
        echo "PASS  $1"
    else
        echo "FAIL  $1"; echo "$out" | sed 's/^/      /'; FAIL=1
    fi
}

echo "==> $("$AST" -V) / chan_dongle $VERSION"
check "module running"            "module show like chan_dongle"       "chan_dongle\.so.*Running"
check "channel type registered"   "core show channeltype Dongle"       "Dongle"
check "CLI: dongle show version"  "dongle show version"                "Version $VERSION"
check "CLI: dongle show devices"  "dongle show devices"                "^ID +Group"
check "app DongleStatus"          "core show application DongleStatus"   "DongleStatus"
check "app DongleSendSMS"         "core show application DongleSendSMS"  "DongleSendSMS"
check "app DongleSendUSSD"        "core show application DongleSendUSSD" "DongleSendUSSD"
check "AMI DongleShowDevices"     "manager show command DongleShowDevices" "DongleShowDevices"
check "AMI DongleSendSMS"         "manager show command DongleSendSMS"     "DongleSendSMS"
check "module unload"             "module unload chan_dongle.so"       "Unloaded chan_dongle"
check "module gone after unload"  "module show like chan_dongle"       "0 modules loaded"
check "module load again"         "module load chan_dongle.so"         "Loaded chan_dongle"
check "module running after load" "module show like chan_dongle"       "chan_dongle\.so.*Running"

if grep -qiE "undefined symbol|Error loading module|segfault" \
        "$T/log/messages.log" "$T/log/console.log" 2>/dev/null; then
    echo "FAIL  loader errors in log:"
    grep -iE "undefined symbol|Error loading module|segfault" \
        "$T/log/messages.log" "$T/log/console.log" | sed 's/^/      /'
    FAIL=1
else
    echo "PASS  no loader errors in log"
fi

[ $FAIL -eq 0 ] && echo "==> SMOKE TEST PASSED" || echo "==> SMOKE TEST FAILED"
exit $FAIL
