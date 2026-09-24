# Start from Fedora Silverblue bootable container base
FROM quay.io/fedora-ostree-desktops/silverblue:44

# Remove pre-installed Fedora Firefox RPM/overrides
RUN dnf -y remove firefox firefox-langpacks || true && \
    rm -f /etc/flatpak/remotes.d/fedora*.flatpakrepo \
          /usr/share/flatpak/remotes.d/fedora*.flatpakrepo

# Install COPR plugin, enable LACT repository, install packages, enable service
RUN dnf -y install dnf5-plugins && \
    dnf -y copr enable ilyaz/LACT && \
    dnf -y install \
    fish \
    distrobox \
    fastfetch \
    htop \
    steam-devices \
    lact \
    && systemctl enable lactd \
    && dnf clean all

# Swap stock kernel for CachyOS's Fedora build (BORE scheduler + sched-ext support)
RUN dnf -y copr enable bieszczaders/kernel-cachyos && \
    dnf -y install kernel-cachyos kernel-cachyos-devel-matched && \
    dnf clean all

# CachyOS tuning: zram/sysctl/udev defaults + auto-nice background scheduling
RUN dnf -y copr enable bieszczaders/kernel-cachyos-addons && \
    dnf -y swap zram-generator-defaults cachyos-settings && \
    dnf -y install ananicy-cpp cachyos-ananicy-rules && \
    systemctl enable ananicy-cpp && \
    dnf clean all

# Copy notification scripts and unit files from repo into system paths
COPY systemdboot/bootc-update-notify /usr/bin/bootc-update-notify
COPY systemdboot/bootc-notifier.service /usr/lib/systemd/user/bootc-notifier.service
COPY systemdboot/bootc-notifier.timer /usr/lib/systemd/user/bootc-notifier.timer

# Set executable permissions and enable the GNOME user timer globally
RUN chmod +x /usr/bin/bootc-update-notify && \
    systemctl --global enable bootc-notifier.timer

# Configure kernel arguments via bootc kargs.d
RUN mkdir -p /usr/lib/bootc/kargs.d && \
    echo 'kargs = ["amd_pstate=disable", "amdgpu.ppfeaturemask=0xffffffff"]' > /usr/lib/bootc/kargs.d/00-custom-hardware.toml
