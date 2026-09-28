# Stock Fedora Silverblue bootable container base.
# The workflow passes the current stable Fedora release; 44 is the fallback
# for local builds without --build-arg.
ARG FEDORA_VERSION=44
FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_VERSION}

# Remove the Firefox RPM and Fedora's Flatpak remotes; Flathub is the only app source.
# A bundled copy of the Flathub remote file lets first boot add it without network.
RUN dnf -y remove firefox firefox-langpacks || true && \
    rm -f /etc/flatpak/remotes.d/fedora*.flatpakrepo \
          /usr/share/flatpak/remotes.d/fedora*.flatpakrepo && \
    mkdir -p /usr/share/cobaltblue && \
    curl -fsSLo /usr/share/cobaltblue/flathub.flatpakrepo \
        https://dl.flathub.org/repo/flathub.flatpakrepo

# RPM Fusion: full ffmpeg and patent-encumbered codecs, plus AMD hardware
# video decoding (H.264/HEVC) via the freeworld VA-API driver.
# --allowerasing replaces Fedora's stripped-down ffmpeg-free and mesa-va-drivers.
RUN dnf -y install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" && \
    dnf -y install --allowerasing \
        ffmpeg \
        mesa-va-drivers-freeworld \
        gstreamer1-plugins-bad-freeworld \
        gstreamer1-plugins-ugly && \
    dnf clean all

# Base packages, plus LACT (AMD GPU control) from COPR
RUN dnf -y install dnf5-plugins && \
    dnf -y copr enable ilyaz/LACT && \
    dnf -y install \
        fish \
        distrobox \
        fastfetch \
        htop \
        jq \
        gamemode \
        steam-devices \
        lact && \
    systemctl enable lactd && \
    systemctl disable NetworkManager-wait-online.service && \
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
    dnf -y install kernel-cachyos; \
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

# Load ntsync at boot so newer Proton builds can use it for faster Windows sync
RUN echo ntsync > /usr/lib/modules-load.d/ntsync.conf

# Kernel arguments:
# - amd_pstate=disable: the board's firmware lacks the CPPC support amd_pstate
#   needs, so it only produced errors at boot; this silences it and keeps acpi-cpufreq
# - amdgpu.ppfeaturemask: unlocks overclock/undervolt controls for LACT
RUN mkdir -p /usr/lib/bootc/kargs.d && \
    echo 'kargs = ["amd_pstate=disable", "amdgpu.ppfeaturemask=0xffffffff"]' \
        > /usr/lib/bootc/kargs.d/00-custom-hardware.toml

# Fail the build early on problems like multiple kernels or a broken /usr layout
RUN bootc container lint
