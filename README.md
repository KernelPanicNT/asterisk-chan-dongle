# chan_dongle — Asterisk channel driver for Huawei 3G modems

[![build](https://github.com/KernelPanicNT/asterisk-chan-dongle/actions/workflows/build.yml/badge.svg)](https://github.com/KernelPanicNT/asterisk-chan-dongle/actions/workflows/build.yml)
[![release](https://img.shields.io/github/v/release/KernelPanicNT/asterisk-chan-dongle?sort=semver)](https://github.com/KernelPanicNT/asterisk-chan-dongle/releases)
[![license](https://img.shields.io/badge/license-GPL--2.0-blue)](LICENSE.txt)

`chan_dongle` turns a Huawei UMTS/3G USB modem with voice support into an
Asterisk channel: place and receive GSM calls, send and receive SMS, and run
USSD codes from the dialplan, the CLI or the Asterisk Manager Interface.

This fork brings the driver to **Debian 13 (trixie)**, **Asterisk 24 LTS**
and **FreePBX 17**. It is based on the maintained
[wdoekes/asterisk-chan-dongle](https://github.com/wdoekes/asterisk-chan-dongle)
line and adds reliability fixes for unattended gateways.

> [!WARNING]
> A SIM card in a GSM gateway can generate real charges. Test with a limited
> plan first, and disable the SIM PIN before use.

---

## Contents

- [Features](#features)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Configuration](#configuration)
- [Dialplan](#dialplan)
- [CLI, applications and AMI](#cli-applications-and-ami)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Versioning and changelog](#versioning-and-changelog)
- [Credits and license](#credits-and-license)

## Features

- Outgoing and incoming voice calls, call waiting, hold and conference
- SMS send and receive: GSM 7-bit (including national language shift
  tables), UCS-2/UTF-16 with emoji, 8-bit text and concatenated messages, plus
  delivery reports (SQLite-backed `smsdb`)
- USSD send and receive
- Device selection by name, group, round robin, provider, IMEI or IMSI
- **Ghost-call protection** (`audiotimeout`): an established call that stops
  receiving audio from the modem is hung up and the modem is reinitialised,
  instead of keeping the call, and any bridged trunk, open indefinitely
- Non-blocking modem I/O and idle AT keep-alive: a hung modem is detected and
  reconnected without blocking Asterisk
- Automatic detection of the Asterisk version and modules directory
  (FreePBX, Debian multiarch)

## Compatibility

### Tested on hardware

| Modem | Host | OS / Asterisk | Driver version |
|---|---|---|---|
| Huawei E1550 | Raspberry Pi | Raspbian 9 / Asterisk 13.20 | 1.1 series (previous production setup) |

Hardware validation of the 2.x series is in progress; this table will be
extended as it is completed. Reports from other setups are welcome; please
open an issue with your modem model, firmware and results.

### Theoretical (validated in CI, no modem attached)

Every combination below is built with warnings as errors, passes the unit
tests and loads, registers and unloads cleanly in a real Asterisk instance
([build workflow](.github/workflows/build.yml)).

| Platform | Architecture | Asterisk | Source |
|---|---|---|---|
| Debian 13 (trixie) | amd64 | 20, 22, **24 LTS** | official source tarball |
| Debian 13 (trixie), e.g. Raspberry Pi 4/5 | arm64 | 22, **24 LTS** | official source tarball |
| FreePBX 17 on Debian 12 (bookworm) | amd64 | 22, 23 | Sangoma `asteriskNN` packages |

Notes:

- FreePBX 17 officially supports Debian 12 only, and its package repository
  is amd64-only. On Raspberry Pi, build Asterisk from source.
- FreePBX 18 (Debian 13) is not released yet.
- Modems: the voice-capable Huawei models supported upstream, such as the
  E1550, E1752, E155X, E169/K3520, E175X, E261, K3715 and K3765. Voice must
  be enabled in the modem firmware.

## Installation

### Debian 13 with Asterisk built from source

```sh
sudo apt install git
git clone https://github.com/KernelPanicNT/asterisk-chan-dongle.git
cd asterisk-chan-dongle
sudo sh ci/install-build-deps.sh        # compiler, autotools, sqlite3
./bootstrap
./configure                             # detects Asterisk version and module dir
make
make check                              # unit tests
sudo make install
```

`configure` takes the Asterisk version from `pkg-config asterisk` or
`asterisk -V`, and the module directory from `astmoddir` in
`/etc/asterisk/asterisk.conf` (falling back to the usual and multiarch paths).
Override them with `--with-astversion=24.0.0`, `--with-asterisk=/path/to/include`
or `DESTDIR=/path/to/modules`.

### FreePBX 17

Install the `asteriskNN-devel` package that matches the Asterisk installed by
FreePBX, then build as above. The complete guide, with trunk, inbound route and
dialplan setup, is in [contrib/freepbx/README.md](contrib/freepbx/README.md).

### Device access

```sh
sudo cp contrib/udev/92-chan-dongle.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
sudo usermod -aG dialout asterisk       # user that runs Asterisk
```

The rule keeps ModemManager away from the modem and grants the `dialout`
group access to its serial ports.

### Verify without touching your configuration

```sh
sh ci/smoke-test.sh
```

This starts an isolated Asterisk instance, with its own config, run and log
directories in a temporary folder, loads the freshly built module and checks
its channel type, CLI commands, applications and AMI actions.

## Configuration

Copy `etc/dongle.conf` to `/etc/asterisk/dongle.conf`. The main options are:

| Option | Section | Description |
|---|---|---|
| `audio`, `data` | device | Audio and AT serial ports (e.g. `/dev/ttyUSB1`, `/dev/ttyUSB2`) |
| `imei`, `imsi` | device | Identify the modem by IMEI/IMSI instead of port; recommended, since ttyUSB numbers change |
| `context` | defaults/device | Dialplan context for incoming calls, SMS and USSD |
| `group` | defaults/device | Group number for `Dongle/gN` and `Dongle/rN` dialing |
| `exten` | defaults/device | Extension for incoming calls when the SIM does not report its number |
| `rxgain`, `txgain` | defaults/device | Fixed audio gain |
| `audiotimeout` | defaults/device | Seconds without modem audio before an active call is hung up (default `30`, `0` disables) |
| `autodeletesms` | defaults/device | Delete SMS from the SIM after reading |
| `resetdongle` | defaults/device | Send `ATZ` during initialisation |
| `callwaiting` | defaults/device | `auto`, `yes` or `no` |
| `dtmf` | defaults/device | `off`, `inband` or `relax` DTMF detection |
| `smsdb`, `csmsttl` | general | SMS database path and lifetime of incomplete multipart messages |

Useful one-off AT commands:

```text
AT^U2DIAG=0                     # modem function only (no CD-ROM / storage)
AT+CCWA=0,0,1                   # disable call waiting
AT^SYSCFG=13,0,3FFFFFFF,0,3     # 2G only, any band, no roaming
AT+CFUN=1,1                     # reset the modem
```

Send them with `dongle cmd dongle0 AT^U2DIAG=0`.

## Dialplan

Incoming calls, SMS and USSD arrive in the device `context`. These channel
variables are set: `DONGLENAME`, `DONGLEPROVIDER`, `DONGLEIMEI`, `DONGLEIMSI`,
`DONGLENUMBER`; for SMS also `SMS`, `SMS_BASE64` and `SMS_TS`; for USSD also
`USSD`, `USSD_BASE64` and `USSD_TYPE`.

```ini
[from-dongle]
exten => _[+0-9].,1,Dial(PJSIP/2001)
exten => sms,1,Verbose(1,SMS from ${CALLERID(num)}: ${BASE64_DECODE(${SMS_BASE64})})
 same => n,Set(FILE(/var/log/asterisk/sms.txt,,,al)=${STRFTIME(${EPOCH},,%F %T)};${CALLERID(num)};${SMS_BASE64})
 same => n,Hangup()
exten => ussd,1,Verbose(1,USSD: ${BASE64_DECODE(${USSD_BASE64})})
 same => n,Hangup()

[to-gsm]
exten => _X.,1,Dial(Dongle/g1/${EXTEN})            ; any free modem in group 1
exten => *100#,1,DongleSendUSSD(dongle0,${EXTEN})
exten => _#X.,1,DongleSendSMS(dongle0,${EXTEN:1},"Please call me",1440,yes)
```

> [!CAUTION]
> SMS text is untrusted input. Never pass `${SMS}` unescaped to `System()`;
> use `SMS_BASE64` or `FILE()` instead.

Dial string forms:

| Dial string | Selects |
|---|---|
| `Dongle/dongle0/NUMBER` | a specific device |
| `Dongle/g1/NUMBER` | first free device in group 1 |
| `Dongle/r1/NUMBER` | round robin in group 1 |
| `Dongle/p:PROVIDER/NUMBER` | by operator name |
| `Dongle/i:IMEI/NUMBER` | by IMEI |
| `Dongle/s:IMSIPREFIX/NUMBER` | by IMSI prefix |

For call quality, apply a jitter buffer and automatic gain control in the
dialplan (`JITTERBUFFER()` and `AGC()` from `func_speex`). Use the `b()` option
of `Dial()` to set them on the outgoing leg.

## CLI, applications and AMI

**CLI:** `dongle show devices`, `dongle show device settings|state|statistics <device>`,
`dongle show version`, `dongle sms <device> <number> <message>`,
`dongle ussd <device> <code>`, `dongle cmd <device> <AT command>`,
`dongle reset <device>`, `dongle start|stop|restart|remove <mode> <device>`
and `dongle reload <mode>`. `<mode>` is one of `now`, `gracefully` or
`when convenient`.

**Applications:** `DongleStatus`, `DongleSendSMS`, `DongleSendUSSD`.

**AMI actions:** `DongleShowDevices`, `DongleSendSMS`, `DongleSendUSSD`,
`DongleSetCCWA`, `DongleReset`, `DongleRestart`, `DongleStop`, `DongleStart`,
`DongleRemove`, `DongleReload`.

**AMI events:** `DongleNewSMS`, `DongleNewSMSBase64`, `DongleNewUSSD`,
`DongleReport`, `DongleStatus`, `DongleCallStateChange`, `DongleCEND`,
`DongleAudioTimeout` and others.

## Troubleshooting

| Symptom | Check |
|---|---|
| Device stays `Not connected` | `ls -l /dev/ttyUSB*`; is the `asterisk` user in `dialout`? Is ModemManager holding the port? |
| Only a CD-ROM / storage device appears | Switch it with `usb-modeswitch`, then `AT^U2DIAG=0` once |
| `timedout while waiting 'OK'` | Wrong `audio`/`data` port order, or a hung modem; replug or `dongle reset` |
| One-way or choppy audio | Prefer 2G (`AT^SYSCFG`), enable `JITTERBUFFER()` and `AGC()` |
| Call hung up with `No audio from the modem` | The ghost-call watchdog fired; the modem stopped streaming audio. See `dongle show device statistics` |

## Development

- `ci/`: scripts shared by CI and local use, for build dependencies,
  Asterisk from source, the FreePBX 17 packages, the module build and the
  smoke test.
- `.devcontainer/`: a Debian 13 + Asterisk 24 environment for GitHub
  Codespaces or VS Code Dev Containers.
- `make check` runs the unit tests (AT parsing, PDU and charset decoding,
  buffers).
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/).

## Versioning and changelog

Releases follow [Semantic Versioning](https://semver.org/). The version lives
in [`VERSION`](VERSION). All notable changes are recorded in
[CHANGELOG.md](CHANGELOG.md) and published with each
[GitHub release](https://github.com/KernelPanicNT/asterisk-chan-dongle/releases).

## Credits and license

Originally written by Artem Makhutov and Dmitry Vagin, later developed by bg111
and maintained upstream by Walter Doekes and contributors. Distributed under the
[GNU General Public License v2](LICENSE.txt); see also
[COPYRIGHT.txt](COPYRIGHT.txt).
