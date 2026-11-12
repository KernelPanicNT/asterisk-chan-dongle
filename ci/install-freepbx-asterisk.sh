#!/bin/sh
# Install the Asterisk packages that FreePBX 17 uses (Sangoma repository
# deb.freepbx.org, the same one sng_freepbx_debian_install.sh configures),
# plus the matching -devel package needed to build chan_dongle.
#
# FreePBX 17 officially supports Debian 12 (bookworm) only.
#
# Usage: ci/install-freepbx-asterisk.sh [asterisk-major]   (default: 22)
set -eu

ASTVER=${1:-22}
REPO=${FREEPBX_REPO:-http://deb.freepbx.org/freepbx17-prod}

SUDO=
[ "$(id -u)" -eq 0 ] || SUDO=sudo

export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq --no-install-recommends wget gnupg ca-certificates

wget -q -O - http://deb.freepbx.org/gpg/aptly-pubkey.asc |
    $SUDO gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/freepbx.gpg
echo "deb [arch=amd64] $REPO bookworm main" |
    $SUDO tee /etc/apt/sources.list.d/freepbx.list >/dev/null

$SUDO apt-get update -qq
$SUDO apt-get install -y -qq "asterisk$ASTVER-core" "asterisk$ASTVER-devel"

# The Sangoma packages declare no Depends: sng_freepbx_debian_install.sh
# installs the runtime libraries separately. Install the same base set...
$SUDO apt-get install -y -qq --no-install-recommends \
    libedit2 libjansson4 libxml2 libxslt1.1 libsqlite3-0 libuuid1 libssl3 \
    libcurl4 libsrtp2-1 liburiparser1 libspeexdsp1 libncurses6 libpopt0 \
    libical3 libneon27 libspandsp2 libresample1 libunbound8 libgmime-3.0-0 \
    libsnmp40 libsybdb5 libiksemel3 libbluetooth3 uuid
$SUDO ldconfig

# ...then resolve whatever the binary still misses (apt-file lookup).
missing=$(ldd /usr/sbin/asterisk | awk '/not found/ {print $1}')
if [ -n "$missing" ]; then
    echo "==> resolving missing libraries: $missing"
    $SUDO apt-get install -y -qq --no-install-recommends apt-file
    $SUDO apt-file update >/dev/null
    for lib in $missing; do
        pkg=$(apt-file search -l "/$lib" | head -n1)
        [ -n "$pkg" ] && $SUDO apt-get install -y -qq --no-install-recommends "$pkg"
    done
    $SUDO ldconfig
fi
if ldd /usr/sbin/asterisk | grep -q "not found"; then
    ldd /usr/sbin/asterisk | grep "not found" >&2
    exit 1
fi

/usr/sbin/asterisk -V
