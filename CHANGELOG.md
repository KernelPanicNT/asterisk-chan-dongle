# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The version number lives in [`VERSION`](VERSION) and is read by `configure.ac`.

## [Unreleased]

## [2.0.0-rc.1] - 2026-11-12

Port of the fork to Debian 13 (trixie), Asterisk 24 LTS and FreePBX 17.

### Added
- Rebased the fork (previously at bg111 `ab93953`, 2016) onto the maintained
  wdoekes/asterisk-chan-dongle line (`7db8e75`, 142 commits), which brings in
  Asterisk 13–22 API support, the SMS database (`smsdb`), GSM7/UCS-2 fixes,
  Turkish SMS decoding and the larger audio write buffer.
- Automatic detection of the Asterisk version in `configure` (`pkg-config
  asterisk`, then `asterisk -V`); `--with-astversion` is now optional.
- Module directory detection from `astmoddir` in `asterisk.conf` and Debian
  multiarch paths (`/usr/lib/<triplet>/asterisk/modules`,
  `/lib/<triplet>/asterisk/modules` used by the FreePBX 17 packages).
- `VERSION` file as the single source of the SemVer version; the revision
  shown by `dongle show version` is now taken from `git describe`.
- CI scripts in `ci/`: build dependencies, Asterisk from source, FreePBX 17
  Asterisk packages, module build, and an isolated runtime smoke test.
- GitHub Actions matrix: Debian 13 × Asterisk 20/22/24 (source) and Debian 12
  × FreePBX 17 Asterisk 22/23 packages; warnings as errors.
- Debian 13 + Asterisk 24 devcontainer for GitHub Codespaces.
- `contrib/udev/92-chan-dongle.rules` (ModemManager ignore, `dialout` access).
- `contrib/freepbx/`: FreePBX 17 guide and `extensions_custom.conf` example.
- `CHANGELOG.md`.

### Changed
- Project URLs now point to KernelPanicNT/asterisk-chan-dongle.
- `AC_PREREQ` raised to 2.69; removed the obsolete `AC_CANONICAL_SYSTEM`
  (autoconf 2.72 on Debian 13).
- Optimisation level `-O6` replaced by `-O2`.
- `make dist` ships `README.md`, `CHANGELOG.md`, `VERSION`, `bootstrap`, `ci/`.

### Removed
- Disabled Travis/GitHub workflow stub.

[Unreleased]: https://github.com/KernelPanicNT/asterisk-chan-dongle/compare/v2.0.0-rc.1...HEAD
[2.0.0-rc.1]: https://github.com/KernelPanicNT/asterisk-chan-dongle/compare/ab93953...v2.0.0-rc.1
