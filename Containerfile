# Start from Fedora Silverblue bootable container base
FROM quay.io/fedora-ostree-desktops/silverblue:44

# Install system packages
RUN dnf -y install \
    systemd-boot-unsigned \
    NetworkManager-openvpn-gnome \
    fish \
    distrobox \
    libnotify \
    && dnf clean all

# Tell bootc to use systemd-boot instead of GRUB2
RUN mkdir -p /usr/lib/bootc/install && \
    echo 'bootloader = "systemd-boot"' > /usr/lib/bootc/install/00-bootloader.toml

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