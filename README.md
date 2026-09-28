# cobaltblue

A custom Fedora Silverblue image for my desktop: gaming on AMD, Rust
development and everyday use. Built daily on GitHub Actions from stock
Fedora Silverblue and published as a signed bootable container image.

## Features

### Base
- Stock **Fedora Silverblue** (GNOME), always on the **current stable Fedora
  release**, detected automatically at build time. Betas are never used.
- The Firefox RPM is removed. Apps come from Flatpak.
- **Flathub is the only Flatpak remote.** Fedora's remotes are removed and a
  boot service makes sure Flathub is configured.

### Codecs (RPM Fusion)
- Full `ffmpeg` in place of Fedora's `ffmpeg-free`
- `mesa-va-drivers-freeworld`: H.264 / HEVC hardware video decoding on AMD
- GStreamer `bad-freeworld` and `ugly` plugins for GNOME apps

### Kernel and system tuning
- **CachyOS kernel** with the BORE scheduler, replacing Fedora's kernel
- **cachyos-settings**: CachyOS zram, sysctl and udev defaults
- **ananicy-cpp** with CachyOS rules: automatic priority for background tasks
- **ntsync** loaded at boot for Proton
- `NetworkManager-wait-online` disabled for faster boot

### GPU and gaming
- **LACT** for AMD GPU control (clocks, undervolt, power limit, fan curve),
  with overdrive unlocked via `amdgpu.ppfeaturemask=0xffffffff`
- **GameMode** daemon, usable from Flatpak Steam with `gamemoderun %command%`
- `steam-devices` udev rules for controllers and VR hardware
- `amd_pstate=disable`, since this board's firmware lacks the CPPC support it needs

### Tools
- `fish`, `distrobox`, `fastfetch`, `htop`, `jq`

### Updates
- Updates are downloaded and **staged automatically** in the background,
  with no automatic reboot.
- A desktop notification appears when a staged update is ready, once per update.
- Images are **signed with cosign**, and the system only accepts signed
  cobaltblue images.

## Tags

| Tag | Meaning |
| --- | --- |
| `latest` | Newest build, follows new Fedora releases automatically |
| `<fedora>` (e.g. `44`) | Newest build for that Fedora release |
| `<fedora>-<date>` (e.g. `44-20260928`) | A specific daily build, for rollbacks |

## Installation

From an existing Fedora Silverblue install:

```sh
# 1. Switch to the image (unverified, to get the signing key onto the system)
rpm-ostree rebase ostree-unverified-registry:ghcr.io/vorpalmace/cobaltblue:latest
systemctl reboot

# 2. Switch to signature-verified updates
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/vorpalmace/cobaltblue:latest
systemctl reboot
```

To control Fedora major upgrades manually, use a release tag such as `:44`
instead of `:latest`, and rebase to the next release when ready.

## After the first boot

```sh
uname -r                  # contains "cachyos"
cat /proc/cmdline         # contains amd_pstate=disable and amdgpu.ppfeaturemask
zramctl                   # zram swap active
systemctl status ananicy-cpp lactd
flatpak remotes           # only flathub
```

If the kernel arguments are missing, add them once:

```sh
rpm-ostree kargs --append=amd_pstate=disable --append=amdgpu.ppfeaturemask=0xffffffff
```

## Building

The image is built by `.github/workflows/build.yml` on every push to `main`,
daily at 04:00 UTC and on manual trigger. Signing requires the `SIGNING_SECRET`
repository secret (the contents of `cosign.key`) and `cosign.pub` committed in
the repository root.

Files under `files/` are copied into the image at the same path, e.g.
`files/usr/bin/bootc-update-notify` becomes `/usr/bin/bootc-update-notify`.
