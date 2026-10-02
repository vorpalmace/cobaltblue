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
  Obsidian, Fragments, Celluloid, MangoHud, and the adw-gtk3 Flatpak themes
- Flathub as the preferred Flatpak remote; Fedora's stays for its preinstalled apps

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
- MangoHud for Flatpak Steam: `MANGOHUD=1 %command%`
- `steam-devices` udev rules for controllers and VR

### Tools
- `fish`, `distrobox`, `fastfetch`, `htop`, `jq`, and `micro`
- fish as the default shell for new users
- Caffeine GNOME extension (enable it in Extensions)
- adw-gtk3 theme so GTK3 apps match libadwaita, Flatpaks included

### Updates
- [uupd](https://github.com/ublue-os/uupd) updates the OS, Flatpaks, and
  distroboxes daily and 5 minutes after boot, skipping metered connections,
  low battery, and heavy load; OS updates apply on reboot
- Notifications only when updates fail
- Firmware updates are manual: `fwupdmgr update`
- Only cosign-signed cobaltblue images are accepted

## Tags

| Tag | Meaning |
| --- | --- |
| `latest` | Newest build, follows Fedora releases |
| `<fedora>` (e.g. `45`) | Newest build for that release |
| `<fedora>-<date>` (e.g. `45-20261002`) | A specific build, for rollbacks (last two weeks) |

## Installation

From Fedora Silverblue:

```sh
sudo bootc switch ghcr.io/vorpalmace/cobaltblue:latest
systemctl reboot
```

The image brings its signing policy, so every later update must be signed.
bootc refuses to switch while rpm-ostree has layered packages.

Use a release tag such as `:45` to control major upgrades manually.

## After the first boot

```sh
bootc status
cat /proc/cmdline         # contains amdgpu.ppfeaturemask=0xffffffff
systemctl status lactd uupd.timer
flatpak remotes           # flathub first, then fedora
```

## Building

`.github/workflows/build.yml` builds on every push to `main` (except README
and LICENSE changes), daily at 01:00 UTC, and on manual trigger. The image is
rechunked into stable layers, so updates only download what changed. About two
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
After a key change, installed systems reject new images until the new
`cosign.pub` is copied to `/etc/pki/containers/cobaltblue.pub`.

Verify an image:

```sh
cosign verify --key cosign.pub ghcr.io/vorpalmace/cobaltblue:latest
```
