# Debian 13 (trixie) + Asterisk built from source, for developing and testing
# chan_dongle in GitHub Codespaces or any devcontainer-capable editor.
FROM debian:13

ARG ASTERISK_VERSION=24
ARG USERNAME=vscode

COPY ci/install-build-deps.sh ci/build-asterisk.sh /tmp/ci/
RUN sh /tmp/ci/install-build-deps.sh --asterisk \
 && apt-get install -y -qq --no-install-recommends sudo gdb valgrind less nano \
        usbutils usb-modeswitch minicom procps \
 && JOBS=$(nproc) sh /tmp/ci/build-asterisk.sh "$ASTERISK_VERSION" /usr/src \
 && rm -rf /usr/src/asterisk-*.tar.gz /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -G dialout "$USERNAME" \
 && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/"$USERNAME"

USER $USERNAME
