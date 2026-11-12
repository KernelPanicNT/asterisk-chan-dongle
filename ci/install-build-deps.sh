#!/bin/sh
# Install the Debian packages needed to build chan_dongle (and, with
# --asterisk, to build Asterisk itself from source).
#
# Usage: ci/install-build-deps.sh [--asterisk]
# Tested on: Debian 12 (bookworm), Debian 13 (trixie)
set -eu

SUDO=
[ "$(id -u)" -eq 0 ] || SUDO=sudo

PKGS="build-essential autoconf automake pkg-config git ca-certificates wget
      libsqlite3-dev sqlite3"

if [ "${1:-}" = "--asterisk" ]; then
    PKGS="$PKGS bzip2 patch libedit-dev libjansson-dev libxml2-dev uuid-dev
          libssl-dev libncurses-dev libcurl4-openssl-dev libsrtp2-dev
          libpopt-dev libnewt-dev xmlstarlet python3"
fi

export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
# shellcheck disable=SC2086
$SUDO apt-get install -y -qq --no-install-recommends $PKGS
