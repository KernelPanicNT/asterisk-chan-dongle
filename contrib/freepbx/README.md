# chan_dongle on FreePBX 17

Tested combinations (see `.github/workflows/build.yml`):

| OS | Asterisk | Source |
|----|----------|--------|
| Debian 12 (FreePBX 17 official) | 22, 23 | Sangoma packages `asteriskNN-core` / `asteriskNN-devel` |
| Debian 13 (trixie) | 20, 22, 24 LTS | Official source tarball |

FreePBX 17 only supports Debian 12 officially; FreePBX 18 (Debian 13) is not
released yet. The module itself builds and runs on Debian 13 + Asterisk 24.

## 1. Build and install

```sh
apt install build-essential autoconf automake pkg-config git libsqlite3-dev usb-modeswitch
apt install asterisk22-devel        # match the asteriskNN package FreePBX installed
git clone https://github.com/KernelPanicNT/asterisk-chan-dongle.git
cd asterisk-chan-dongle
./bootstrap && ./configure          # Asterisk version and module dir are auto-detected
make && make install                # installs into astmoddir from /etc/asterisk/asterisk.conf
```

## 2. Device permissions

```sh
cp contrib/udev/92-chan-dongle.rules /etc/udev/rules.d/
udevadm control --reload && udevadm trigger
usermod -aG dialout asterisk
```

If the modem shows up as a CD-ROM / storage device, switch it with
`usb-modeswitch`, and run once `AT^U2DIAG=0` on it (see README).

## 3. Configuration

```sh
cp etc/dongle.conf /etc/asterisk/dongle.conf
chown asterisk:asterisk /etc/asterisk/dongle.conf
```

Edit `/etc/asterisk/dongle.conf`: set `context=from-dongle` and identify each
modem by `imei=` (recommended; ttyUSB numbers change across reboots) or by
`audio=`/`data=`. Append `contrib/freepbx/extensions_custom.conf` to
`/etc/asterisk/extensions_custom.conf`.

Load the module at boot. FreePBX autoloads modules, so just run
`fwconsole restart` and check with `asterisk -rx "dongle show devices"`.

## 4. Outbound trunk

*Connectivity → Trunks → Add Custom Trunk*

- Custom Dial String: `Dongle/g1/$OUTNUM$` (group 1, see `group=` in dongle.conf),
  or `Dongle/dongle0/$OUTNUM$` for one specific modem, or `Dongle/r1/$OUTNUM$`
  for round-robin in group 1.
- Maximum channels: number of modems in that group.

Then point an Outbound Route at the trunk.

## 5. Inbound

Create an *Inbound Route* whose DID is the SIM's number as reported by
`dongle show devices` (or the `exten=` you set in dongle.conf).
