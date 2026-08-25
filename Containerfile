# Start from Fedora Silverblue bootable container base
FROM quay.io/fedora-ostree-desktops/silverblue:44

# Install system packages
RUN dnf -y install \
    NetworkManager-openvpn-gnome \
    fish \
    distrobox \
    libnotify \
    fastfetch \
    htop \
    && dnf clean all

# Strip GRUB/bootupd so bootc falls back to systemd-boot by default and install the actual systemd-boot binaries
RUN dnf remove -y grub2-efi-x64 grub2-efi-x64-cdboot shim-x64 grub2-tools grub2-tools-minimal grubby bootupd || true
RUN dnf install -y systemd-boot-unsigned && dnf clean all

# Set Fish as default shell & enable Podman socket
RUN chsh -s /usr/bin/fish
RUN systemctl enable podman.socket

# Copy notification scripts and unit files from repo into system paths
COPY systemdboot/bootc-update-notify /usr/bin/bootc-update-notify
COPY systemdboot/bootc-notifier.service /usr/lib/systemd/user/bootc-notifier.service
COPY systemdboot/bootc-notifier.timer /usr/lib/systemd/user/bootc-notifier.timer

# Set executable permissions and enable the GNOME user timer globally
RUN chmod +x /usr/bin/bootc-update-notify
RUN systemctl --global enable bootc-notifier.timer