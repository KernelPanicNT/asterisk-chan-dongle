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

asterisk -V
