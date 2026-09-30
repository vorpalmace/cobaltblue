# cobaltblue

Custom Fedora Silverblue image for gaming, development, and everyday use.
Built daily and published as a signed bootable container image.

## Features

### Base
- Stock Fedora Silverblue on the current stable release, detected at build time
- Firefox RPM removed
- Flathub as the only Flatpak remote

### Codecs (RPM Fusion)
- Full `ffmpeg` instead of `ffmpeg-free`
- `mesa-va-drivers-freeworld` for H.264/HEVC hardware decoding
- GStreamer `bad-freeworld` and `ugly` plugins

### System
- `ntsync` loaded at boot for Proton
- `NetworkManager-wait-online` disabled

### Gaming
- LACT for GPU clocks, undervolting, power limit, and fan curve, with overdrive
  unlocked via `amdgpu.ppfeaturemask=0xffffffff`
- GameMode, usable from Flatpak Steam with `gamemoderun %command%`
- `steam-devices` udev rules for controllers and VR

### Tools
- `fish`, `distrobox`, `fastfetch`, `htop`, and `jq`

### Updates
- GNOME Software handles OS and Flatpak updates
- Only cosign-signed cobaltblue images are accepted

## Tags

| Tag | Meaning |
| --- | --- |
| `latest` | Newest build, follows Fedora releases |
| `<fedora>` (e.g. `44`) | Newest build for that release |
| `<fedora>-<date>` (e.g. `44-20260928`) | A specific build, for rollbacks |

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
lsmod | grep ntsync       # ntsync loaded
systemctl status lactd
flatpak remotes           # only flathub
```

If the kernel argument is missing:

```sh
rpm-ostree kargs --append=amdgpu.ppfeaturemask=0xffffffff
```

## Building

`.github/workflows/build.yml` builds on every push to `main`, daily at
04:00 UTC, and on manual trigger. Signing needs `cosign.pub` in the repository
root and two repository secrets: `SIGNING_SECRET` (the contents of `cosign.key`)
and `COSIGN_PASSWORD`.

Files under `files/` are copied into the image at the same path.
