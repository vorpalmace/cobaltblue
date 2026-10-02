# cobaltblue

Custom Fedora Silverblue image for gaming, development, and everyday use.
Built daily and published as a signed bootable container image.

## Features

### Base
- Stock Fedora Silverblue on the newest release, including pre-releases once a
  release branches from Rawhide
- Firefox RPM removed
- Bazaar instead of GNOME Software
- distrobox instead of toolbox
- Installed from Flathub on first boot: Bazaar, Zen Browser, Steam, ONLYOFFICE,
  Obsidian, Fragments, and Celluloid
- Flathub as the only Flatpak remote

### Codecs (RPM Fusion)
- Full `ffmpeg` instead of `ffmpeg-free`
- `mesa-va-drivers-freeworld` for H.264/HEVC hardware decoding
- GStreamer `bad-freeworld` and `ugly` plugins

### System
- `NetworkManager-wait-online` disabled
- Services that hang on shutdown are killed after 15 seconds
- Rescue and emergency mode bootable from GRUB despite the locked root account
  (from CoreOS)

### Gaming
- LACT for GPU clocks, undervolting, power limit, and fan curve, with overdrive
  unlocked via `amdgpu.ppfeaturemask=0xffffffff`
- GameMode, usable from Flatpak Steam with `gamemoderun %command%`
- `steam-devices` udev rules for controllers and VR

### Tools
- `fish`, `distrobox`, `fastfetch`, `htop`, `jq`, and `micro`
- fish as the default shell for new users

### Updates
- Daily automatic updates on unmetered connections, following Universal Blue:
  OS updates are staged and applied on reboot, Flatpaks update in place
- Firmware updates are manual: `fwupdmgr update`
- Only cosign-signed cobaltblue images are accepted

## Tags

| Tag | Meaning |
| --- | --- |
| `latest` | Newest build, follows Fedora releases |
| `<fedora>` (e.g. `44`) | Newest build for that release |
| `<fedora>-<date>` (e.g. `44-20260928`) | A specific build, for rollbacks (last two weeks) |

## Installation

From Fedora Silverblue:

```sh
# 1. Unverified rebase, to install the signing key
rpm-ostree rebase ostree-unverified-registry:ghcr.io/vorpalmace/cobaltblue:latest
systemctl reboot

# 2. Switch to signed updates
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/vorpalmace/cobaltblue:latest
systemctl reboot
```

Use a release tag such as `:44` to control major upgrades manually.

## After the first boot

```sh
rpm-ostree status         # origin starts with ostree-image-signed:
cat /proc/cmdline         # contains amdgpu.ppfeaturemask=0xffffffff
systemctl status lactd rpm-ostreed-automatic.timer flatpak-system-update.timer
systemctl --user status flatpak-user-update.timer
flatpak remotes           # only flathub
```

If the kernel argument is missing:

```sh
rpm-ostree kargs --append=amdgpu.ppfeaturemask=0xffffffff
```

## Building

`.github/workflows/build.yml` builds on every push to `main` (except README
and LICENSE changes), daily at 01:00 UTC, and on manual trigger. About two
weeks of builds are kept.

Files under `files/` are copied into the image at the same path.

## Signing

Create a key pair:

```sh
cosign generate-key-pair   # leave the password empty
```

Commit `cosign.pub`, keep `cosign.key` out of the repository, and add its
contents as the `SIGNING_SECRET` repository secret.

The image installs the public key as `/etc/pki/containers/cobaltblue.pub`, and
`/etc/containers/policy.json` only accepts cobaltblue images signed with it.
After a key change, installed systems reject new images until they rebase
unverified once more.

Verify an image:

```sh
cosign verify --key cosign.pub ghcr.io/vorpalmace/cobaltblue:latest
```
