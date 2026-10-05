# Workflow passes the newest release; 45 is the local-build fallback
ARG FEDORA_VERSION=45
FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_VERSION}

# Drop Firefox, tour, help, and apps replaced by Bazaar, distrobox, and Extension Manager
RUN dnf -y remove firefox firefox-langpacks gnome-software gnome-software-rpm-ostree toolbox \
        gnome-extensions-app gnome-tour yelp && \
    mkdir -p /usr/share/cobaltblue && \
    curl -fsSLo /usr/share/cobaltblue/flathub.flatpakrepo \
        https://dl.flathub.org/repo/flathub.flatpakrepo

# RPM Fusion codecs and AMD VA-API; --allowerasing replaces Fedora's -free builds
RUN dnf -y install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" && \
    dnf -y install --allowerasing \
        ffmpeg \
        mesa-va-drivers-freeworld \
        gstreamer1-plugins-bad-freeworld \
        gstreamer1-plugins-ugly && \
    dnf clean all

# Base packages; LACT and uupd (ublue's updater) from COPR
RUN dnf -y install dnf5-plugins && \
    dnf -y copr enable ilyaz/LACT && \
    dnf -y copr enable ublue-os/packages && \
    dnf -y install \
        adw-gtk3-theme \
        distrobox \
        fastfetch \
        fish \
        gamemode \
        gnome-shell-extension-caffeine \
        htop \
        jq \
        lact \
        micro \
        steam-devices \
        uupd && \
    dnf -y copr disable ilyaz/LACT && \
    dnf -y copr disable ublue-os/packages && \
    dnf clean all

# GTK3 light/dark auto switcher from extensions.gnome.org; skipped with a warning if this GNOME isn't supported yet
RUN UUID=legacyschemeautoswitcher@joshimukul29.gmail.com && \
    SHELL_VER="$(rpm -q --qf '%{VERSION}' gnome-shell | cut -d. -f1)" && \
    curl -fsSLo /tmp/ext.zip \
        "https://extensions.gnome.org/download-extension/$UUID.shell-extension.zip?shell_version=$SHELL_VER" && \
    if python3 -c 'import json, sys, zipfile; \
            sys.exit(sys.argv[2] not in json.load(zipfile.ZipFile(sys.argv[1]).open("metadata.json"))["shell-version"])' \
            /tmp/ext.zip "$SHELL_VER"; then \
        python3 -m zipfile -e /tmp/ext.zip "/usr/share/gnome-shell/extensions/$UUID"; \
    else \
        echo "::warning::$UUID does not support GNOME $SHELL_VER yet, skipped"; \
    fi && \
    rm /tmp/ext.zip

# files/ mirrors the root filesystem
COPY files/ /
COPY cosign.pub /etc/pki/containers/cobaltblue.pub

# Services, fish as default shell, GSettings defaults
RUN systemctl enable flathub-setup.service flatpak-preinstall.service lactd.service uupd.timer && \
    systemctl disable NetworkManager-wait-online.service && \
    sed -i 's|^SHELL=.*|SHELL=/usr/bin/fish|' /etc/default/useradd && \
    glib-compile-schemas /usr/share/glib-2.0/schemas

# Signed cobaltblue only (reject default, others allowed per transport)
RUN jq '.default = [{"type": "reject"}] \
        | reduce ("docker", "docker-archive", "docker-daemon", "oci", "oci-archive", "dir", "containers-storage") as $t \
            (.; .transports[$t][""] //= [{"type": "insecureAcceptAnything"}]) \
        | .transports.docker["ghcr.io/vorpalmace/cobaltblue"] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/cobaltblue.pub", "signedIdentity": {"type": "matchRepository"}}]' \
        /usr/share/containers/policy.json > /tmp/policy.json && \
    mv /tmp/policy.json /etc/containers/policy.json

# Catch multiple kernels, broken /usr layout, etc.
RUN bootc container lint