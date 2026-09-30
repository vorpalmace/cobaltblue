# Workflow passes the current release; 44 is the local-build fallback
ARG FEDORA_VERSION=44
FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_VERSION}

# Flathub only: drop Firefox RPM and Fedora remotes, bundle Flathub's repo file
RUN dnf -y remove firefox firefox-langpacks || true && \
    rm -f /etc/flatpak/remotes.d/fedora*.flatpakrepo \
          /usr/share/flatpak/remotes.d/fedora*.flatpakrepo && \
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

# Base packages; LACT from COPR
RUN dnf -y install dnf5-plugins && \
    dnf -y copr enable ilyaz/LACT && \
    dnf -y install \
        fish \
        distrobox \
        fastfetch \
        htop \
        micro \
        vim-enhanced \
        jq \
        gamemode \
        steam-devices \
        lact && \
    systemctl enable lactd && \
    systemctl disable NetworkManager-wait-online.service && \
    dnf clean all

# files/ mirrors the root filesystem
COPY files/ /
COPY cosign.pub /etc/pki/containers/cobaltblue.pub

RUN systemctl enable flathub-setup.service rpm-ostreed-automatic.timer

# Signed cobaltblue only; rpm-ostree needs a reject default, so allow others per transport
RUN jq '.default = [{"type": "reject"}] \
        | reduce ("docker", "docker-archive", "docker-daemon", "oci", "oci-archive", "dir", "containers-storage") as $t \
            (.; .transports[$t][""] //= [{"type": "insecureAcceptAnything"}]) \
        | .transports.docker["ghcr.io/vorpalmace/cobaltblue"] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/cobaltblue.pub", "signedIdentity": {"type": "matchRepository"}}]' \
        /etc/containers/policy.json > /tmp/policy.json && \
    mv /tmp/policy.json /etc/containers/policy.json

# Unlock LACT overclock/undervolt controls
RUN mkdir -p /usr/lib/bootc/kargs.d && \
    echo 'kargs = ["amdgpu.ppfeaturemask=0xffffffff"]' \
        > /usr/lib/bootc/kargs.d/00-custom-hardware.toml

# Catch multiple kernels, broken /usr layout, etc.
RUN bootc container lint