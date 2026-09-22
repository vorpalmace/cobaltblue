# Start from Fedora Silverblue bootable container base
FROM quay.io/fedora-ostree-desktops/silverblue:44

# Remove pre-installed Fedora Firefox RPM/overrides
RUN dnf -y remove firefox || true && \
    rm -f /etc/flatpak/remotes.d/fedora*.flatpakrepo \
          /usr/share/flatpak/remotes.d/fedora*.flatpakrepo

# Install COPR plugin, enable LACT repository (-y required), install packages, enable service
RUN dnf -y install dnf-plugins-core && \
    dnf -y copr enable ilyaz/LACT && \
    dnf -y install \
    # NetworkManager-openvpn-gnome \
    fish \
    distrobox \
    fastfetch \
    htop \
    steam-devices \
    lact \
    && systemctl enable lactd \
    && dnf clean all

# Enable Podman socket
RUN systemctl enable podman.socket

# Copy notification scripts and unit files from repo into system paths
COPY systemdboot/bootc-update-notify /usr/bin/bootc-update-notify
COPY systemdboot/bootc-notifier.service /usr/lib/systemd/user/bootc-notifier.service
COPY systemdboot/bootc-notifier.timer /usr/lib/systemd/user/bootc-notifier.timer

# Set executable permissions and enable the GNOME user timer globally
RUN chmod +x /usr/bin/bootc-update-notify && \
    systemctl --global enable bootc-notifier.timer

# Configure kernel arguments via bootc kargs.d
RUN mkdir -p /usr/lib/bootc/kargs.d && \
    echo 'kargs = ["amd_pstate=disable", "amdgpu.ppfeaturemask=0xffffffff"]' > /usr/lib/bootc/kargs.d/00-custom-hardware.conf
