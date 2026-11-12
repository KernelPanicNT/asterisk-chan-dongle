#!/bin/sh
# Download, build and install Asterisk from the official source tarball.
# Intended for CI containers and throw-away test VMs, NOT for a FreePBX
# server (FreePBX installs its own Asterisk packages).
#
# Usage: ci/build-asterisk.sh <major|full-version> [workdir]
#   ci/build-asterisk.sh 24          -> latest asterisk-24-current
#   ci/build-asterisk.sh 22.12.0     -> exact release
set -eu

VER=${1:?usage: $0 <major|full-version> [workdir]}
WORK=${2:-/usr/src}
JOBS=${JOBS:-$(nproc)}
BASE=https://downloads.asterisk.org/pub/telephony/asterisk

SUDO=
[ "$(id -u)" -eq 0 ] || SUDO=sudo

case "$VER" in
    *.*) TARBALL=asterisk-$VER.tar.gz ;;
    *)   TARBALL=asterisk-$VER-current.tar.gz ;;
esac

$SUDO mkdir -p "$WORK"
$SUDO chown "$(id -u):$(id -g)" "$WORK"
cd "$WORK"
wget -q -O "$TARBALL" "$BASE/$TARBALL" || wget -q -O "$TARBALL" "$BASE/releases/$TARBALL"
SRCDIR=$(tar tzf "$TARBALL" | head -n1 | cut -d/ -f1)
rm -rf "$SRCDIR"
tar xzf "$TARBALL"
cd "$SRCDIR"
echo "==> Building $SRCDIR with $JOBS jobs"

# pjproject is not needed to test chan_dongle; skipping it keeps the build
# fast and avoids a network download during configure.
./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc \
    --localstatedir=/var --without-pjproject-bundled --with-jansson-bundled=no \
    >configure.log 2>&1 || { tail -n 50 configure.log; exit 1; }

make -s menuselect.makeopts
# Portable binary (no -march=native) and no external sound downloads.
menuselect/menuselect --disable BUILD_NATIVE \
    --disable-category MENUSELECT_CORE_SOUNDS \
    --disable-category MENUSELECT_MOH \
    --disable-category MENUSELECT_EXTRA_SOUNDS \
    menuselect.makeopts

make -s -j"$JOBS" >build.log 2>&1 || { tail -n 80 build.log; exit 1; }
$SUDO make -s install install-headers >install.log 2>&1 || { tail -n 50 install.log; exit 1; }
[ -f /etc/asterisk/asterisk.conf ] || $SUDO make -s samples >/dev/null 2>&1
$SUDO ldconfig

asterisk -V
