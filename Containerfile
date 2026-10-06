# Workflow passes the newest release; 45 is the local-build fallback
ARG FEDORA_VERSION=45
FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_VERSION}

# Drop Firefox, tour, help, Fedora logo, third-party repo switch, totem's thumbnailer (ffmpegthumbnailer replaces it),
# Chromium/Firefox defaults, Japanese input, and apps replaced by Bazaar, distrobox, and Extension Manager
RUN dnf -y remove firefox firefox-langpacks gnome-software gnome-software-rpm-ostree toolbox \
        gnome-extensions-app gnome-tour yelp gnome-shell-extension-background-logo \
        fedora-third-party totem-video-thumbnailer \
        fedora-bookmarks fedora-chromium-config fedora-chromium-config-gnome \
        ibus-anthy ibus-hangul ibus-libpinyin ibus-m17n ibus-typing-booster && \
    mkdir -p /usr/share/cobaltblue && \
    curl -fsSLo /usr/share/cobaltblue/flathub.flatpakrepo \
        https://dl.flathub.org/repo/flathub.flatpakrepo

# Video thumbnails for all codecs; libavcodec-freeworld (RPM Fusion) overrides Fedora's libavcodec-free
RUN dnf -y install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" && \
    dnf -y install ffmpegthumbnailer libavcodec-freeworld && \
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

# GTK3 light/dark auto switcher from extensions.gnome.org; skipped with a warning if unavailable or unsupported
RUN UUID=legacyschemeautoswitcher@joshimukul29.gmail.com && \
    SHELL_VER="$(rpm -q --qf '%{VERSION}' gnome-shell | cut -d. -f1)" && \
    if ! curl -fsSLo /tmp/ext.zip \
            "https://extensions.gnome.org/download-extension/$UUID.shell-extension.zip?shell_version=$SHELL_VER"; then \
        echo "::warning::$UUID download failed, skipped"; \
    elif python3 -c 'import json, sys, zipfile; \
            sys.exit(sys.argv[2] not in json.load(zipfile.ZipFile(sys.argv[1]).open("metadata.json"))["shell-version"])' \
            /tmp/ext.zip "$SHELL_VER"; then \
        python3 -m zipfile -e /tmp/ext.zip "/usr/share/gnome-shell/extensions/$UUID"; \
    else \
        echo "::warning::$UUID does not support GNOME $SHELL_VER yet, skipped"; \
    fi && \
    rm -f /tmp/ext.zip

# files/ mirrors the root filesystem
COPY files/ /
COPY cosign.pub /etc/pki/containers/cobaltblue.pub

# Services, uupd as the only updater, GSettings defaults
RUN systemctl enable flathub-setup.service flatpak-preinstall.service lactd.service uupd.timer && \
    systemctl mask rpm-ostreed-automatic.timer bootc-fetch-apply-updates.timer && \
    glib-compile-schemas /usr/share/glib-2.0/schemas

# Signed cobaltblue only (reject default, others allowed per transport)
RUN jq '.default = [{"type": "reject"}] \
        | reduce ("docker", "docker-archive", "docker-daemon", "oci", "oci-archive", "dir", "containers-storage") as $t \
            (.; .transports[$t][""] //= [{"type": "insecureAcceptAnything"}]) \
        | .transports.docker["ghcr.io/vorpalmace/cobaltblue"] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/cobaltblue.pub", "signedIdentity": {"type": "matchRepository"}}]' \
        /usr/share/containers/policy.json > /tmp/policy.json && \
    mv /tmp/policy.json /etc/containers/policy.json

# Leave /var empty for bootc; catch multiple kernels, broken /usr layout, etc.
RUN rm -rf /var/cache/* /var/log/* /tmp/* && \
    bootc container lint
