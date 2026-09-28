# Universal Blue's Silverblue base: stock Silverblue plus RPM Fusion codecs,
# hardware video decoding and common hardware support
FROM ghcr.io/ublue-os/silverblue-main:44

# Remove the Firefox RPM and Fedora's Flatpak remotes; Flathub is the only app source.
# A bundled copy of the Flathub remote file lets first boot add it without network.
RUN dnf -y remove firefox firefox-langpacks || true && \
    rm -f /etc/flatpak/remotes.d/fedora*.flatpakrepo \
          /usr/share/flatpak/remotes.d/fedora*.flatpakrepo && \
    mkdir -p /usr/share/cobaltblue && \
    curl -fsSLo /usr/share/cobaltblue/flathub.flatpakrepo \
        https://dl.flathub.org/repo/flathub.flatpakrepo

# Base packages, plus LACT (AMD GPU control) from COPR
RUN dnf -y install dnf5-plugins && \
    dnf -y copr enable ilyaz/LACT && \
    dnf -y install \
        fish \
        distrobox \
        fastfetch \
        htop \
        jq \
        steam-devices \
        lact && \
    systemctl enable lactd && \
    dnf clean all

# Replace the stock kernel with CachyOS's build (BORE scheduler + sched-ext).
# Ostree images must contain exactly one kernel, so the stock one is removed
# first, and the initramfs is generated explicitly because container builds
# can skip it.
RUN set -eux; \
    OLD_PKGS="$(rpm -qa --qf '%{NAME}\n' 'kernel' 'kernel-core' 'kernel-modules*' 'kernel-uki-virt*' || true)"; \
    if [ -n "$OLD_PKGS" ]; then rpm --erase --nodeps $OLD_PKGS; fi; \
    rm -rf /usr/lib/modules/*; \
    dnf -y copr enable bieszczaders/kernel-cachyos; \
    dnf -y install kernel-cachyos kernel-cachyos-devel-matched; \
    test "$(ls /usr/lib/modules | wc -l)" -eq 1; \
    KVER="$(ls /usr/lib/modules)"; \
    dracut --no-hostonly --kver "$KVER" --reproducible --zstd -v --add ostree \
        -f "/usr/lib/modules/$KVER/initramfs.img"; \
    dnf clean all

# CachyOS tuning: zram/sysctl/udev defaults + auto-nice background scheduling
RUN dnf -y copr enable bieszczaders/kernel-cachyos-addons && \
    dnf -y swap zram-generator-defaults cachyos-settings && \
    dnf -y install ananicy-cpp cachyos-ananicy-rules && \
    systemctl enable ananicy-cpp && \
    dnf clean all

# Repo files mirror the root filesystem: notifier, Flathub setup, signing config
COPY files/ /
COPY cosign.pub /etc/pki/containers/cobaltblue.pub

RUN chmod +x /usr/bin/bootc-update-notify && \
    systemctl --global enable bootc-notifier.timer && \
    systemctl enable flathub-setup.service

# Download and stage updates automatically in the background (no auto reboot);
# the notifier then tells you when a reboot will apply them
RUN sed -i 's/^#\?AutomaticUpdatePolicy=.*/AutomaticUpdatePolicy=stage/' /etc/rpm-ostreed.conf && \
    grep -q '^AutomaticUpdatePolicy=stage' /etc/rpm-ostreed.conf && \
    systemctl enable rpm-ostreed-automatic.timer

# Only accept cobaltblue images signed with this repo's cosign key
RUN jq '.transports.docker["ghcr.io/vorpalmace/cobaltblue"] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/cobaltblue.pub", "signedIdentity": {"type": "matchRepository"}}]' \
        /etc/containers/policy.json > /tmp/policy.json && \
    mv /tmp/policy.json /etc/containers/policy.json

# Kernel arguments:
# - amd_pstate=disable: the board's firmware lacks the CPPC support amd_pstate
#   needs, so it only produced errors at boot; this silences it and keeps acpi-cpufreq
# - amdgpu.ppfeaturemask: unlocks overclock/undervolt controls for LACT
RUN mkdir -p /usr/lib/bootc/kargs.d && \
    echo 'kargs = ["amd_pstate=disable", "amdgpu.ppfeaturemask=0xffffffff"]' \
        > /usr/lib/bootc/kargs.d/00-custom-hardware.toml

# Fail the build early on problems like multiple kernels or a broken /usr layout
RUN bootc container lint
