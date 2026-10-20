# Containerfile: Base image for PenguinOS
FROM quay.io/fedora-ostree-desktops/kinoite:43

# 1. Enable Non-Free & RPM Fusion Repositories (Codecs, Drivers)
RUN FEDORA_VER=$(rpm -E %fedora) && \
    (curl -fsSL --retry 5 --retry-connrefused -o /tmp/rf-free.rpm \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm || \
     curl -fsSL --retry 5 --retry-connrefused -o /tmp/rf-free.rpm \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm) && \
    (curl -fsSL --retry 5 --retry-connrefused -o /tmp/rf-nonfree.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm || \
     curl -fsSL --retry 5 --retry-connrefused -o /tmp/rf-nonfree.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm) && \
    rpm-ostree install -y /tmp/rf-free.rpm /tmp/rf-nonfree.rpm && \
    rm -f /tmp/rf-free.rpm /tmp/rf-nonfree.rpm


# 2. Install Complete Codecs, Media Stack & Hardware Acceleration
RUN rpm-ostree override remove \
        mesa-va-drivers \
        libavcodec-free \
        libavdevice-free \
        libavfilter-free \
        libavformat-free \
        libavutil-free \
        libpostproc-free \
        libswresample-free \
        libswscale-free \
        ffmpeg-free \
        --install mesa-va-drivers-freeworld \
        --install ffmpeg && \
    rpm-ostree install -y \
        gstreamer1-plugins-bad-freeworld \
        gstreamer1-plugins-ugly \
        gstreamer1-libav \
        intel-media-driver \
        libva-intel-driver \
        libva-utils \
        vdpauinfo

# 3. Install Gaming, GPU Libraries, Core Runtimes & Desktop Apps
RUN rpm-ostree install -y \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers.i686 \
    vulkan-tools \
    mangohud \
    gamescope \
    distrobox \
    podman \
    pipewire-utils \
    telegram-desktop \
    playerctl \
    brightnessctl \
    python3-pyqt6 \
    steam-devices

# 4. Install Drawing Tablet Drivers (Huion, Wacom) & Input Framework
RUN rpm-ostree install -y \
    xorg-x11-drv-wacom \
    libwacom \
    kcm_wacomtablet \
    fcitx5 \
    fcitx5-configtool \
    kcm-fcitx5

# 5. Install OpenBangla Keyboard (Copr repository)
RUN curl -fsSL -o /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:badshah:openbangla-keyboard.repo \
        https://copr.fedorainfracloud.org/coprs/badshah/openbangla-keyboard/repo/fedora-43/badshah-openbangla-keyboard-fedora-43.repo && \
    rpm-ostree install -y fcitx-openbangla

# 6. Install Android App Subsystem (Waydroid)
RUN rpm-ostree install -y waydroid

# 7. Install Wireless, USB Wi-Fi Drivers, Firmware & Networking Essentials
RUN rpm-ostree install -y \
    kde-connect \
    avahi \
    firewalld \
    linux-firmware \
    realtek-firmware \
    mediatek-firmware \
    mt7xxx-firmware \
    atheros-firmware \
    brcmfmac-firmware \
    b43-openfwwf \
    iwlegacy-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    zd1211-firmware \
    libertas-firmware \
    wireless-regdb \
    NetworkManager-wifi \
    wpa_supplicant \
    iw \
    rfkill \
    usb_modeswitch \
    usb_modeswitch-data


# 8. Configure Firewall Policies (KDE Connect & Waydroid)
RUN if command -v firewall-offline-cmd >/dev/null 2>&1; then \
        firewall-offline-cmd --zone=FedoraWorkstation --add-service=kde-connect || true; \
        firewall-offline-cmd --zone=trusted --add-service=kde-connect || true; \
        firewall-offline-cmd --zone=trusted --add-interface=waydroid0 || true; \
    fi

# 8b. Pre-configure Flathub repository, Steam gamepad & USB Wi-Fi udev rules, and kernel modules
RUN mkdir -p /etc/flatpak/remotes.d /usr/lib/udev/rules.d /etc/udev/rules.d /usr/lib/modules-load.d /etc/modules-load.d && \
    curl -fsSL https://dl.flathub.org/repo/flathub.flatpakrepo -o /etc/flatpak/remotes.d/flathub.flatpakrepo || true
COPY ./system/udev/*.rules /usr/lib/udev/rules.d/
COPY ./system/udev/*.rules /etc/udev/rules.d/
COPY ./system/modules/penguin-wifi.conf /usr/lib/modules-load.d/penguin-wifi.conf
COPY ./system/modules/penguin-wifi.conf /etc/modules-load.d/penguin-wifi.conf


# 9. Install storytold/craft-launcher (Official linux-x86_64 release with complete assets)
RUN mkdir -p /tmp/craft-launcher && \
    curl -fsSL https://github.com/storytold/craft-launcher/releases/download/v0.3.2/artcraft-launcher-0.3.2-linux-x86_64.tar.gz | tar -xz -C /tmp/craft-launcher --strip-components=1 && \
    cp /tmp/craft-launcher/bin/artcraft-launcher /usr/bin/craft-launcher && \
    cp /tmp/craft-launcher/bin/artcraft-launcher /usr/bin/artcraft-launcher && \
    chmod 755 /usr/bin/craft-launcher /usr/bin/artcraft-launcher && \
    cp -r /tmp/craft-launcher/share/icons/* /usr/share/icons/ && \
    cp -r /tmp/craft-launcher/share/icons/hicolor/scalable/apps/ai.storyteller.artcraft-launcher.svg /usr/share/icons/hicolor/scalable/apps/craft-launcher.svg || true && \
    cp -r /tmp/craft-launcher/share/icons/hicolor/512x512/apps/ai.storyteller.artcraft-launcher.png /usr/share/pixmaps/craft-launcher.png || true && \
    cp /tmp/craft-launcher/share/applications/ai.storyteller.artcraft-launcher.desktop /usr/share/applications/craft-launcher.desktop && \
    sed -i 's|Exec=.*|Exec=/usr/bin/craft-launcher|g' /usr/share/applications/craft-launcher.desktop && \
    sed -i 's|Icon=.*|Icon=craft-launcher|g' /usr/share/applications/craft-launcher.desktop && \
    rm -rf /tmp/craft-launcher

# 10. Configure Default Panel Launchers & Kickoff Start Button in Plasma layout template
RUN if [ -f /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js ]; then \
        sed -i 's|preferred://browser|preferred://browser,applications:craft-launcher.desktop|g' \
            /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js || true; \
        sed -i 's|panel\.addWidget("org\.kde\.plasma\.kickoff")|var ko = panel\.addWidget("org\.kde\.plasma\.kickoff"); ko\.currentConfigGroup = ["General"]; ko\.writeConfig("icon", "penguinos-logo");|g' \
            /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js || true; \
    fi

# 11. Setup Services, Utilities & Scripts (in /usr/bin for immutable OSTree)
COPY ./system/penguin-update.service /etc/systemd/system/penguin-update.service
COPY ./system/penguin-update.timer /etc/systemd/system/penguin-update.timer
COPY ./system/penguin-firstboot-flatpaks.service /etc/systemd/system/penguin-firstboot-flatpaks.service
COPY ./scripts/penguin-welcome /usr/bin/penguin-welcome
COPY ./scripts/penguin-pin-taskbar /usr/bin/penguin-pin-taskbar
COPY ./scripts/penguin-launch-app /usr/bin/penguin-launch-app
COPY ./scripts/penguin-install-apps /usr/bin/penguin-install-apps
COPY ./penguin-assistant /usr/share/penguin-assistant
RUN chmod +x /usr/bin/penguin-welcome /usr/bin/penguin-pin-taskbar /usr/bin/penguin-launch-app /usr/bin/penguin-install-apps && \
    chmod +x /usr/share/penguin-assistant/bin/penguin-assistant && \
    ln -sf /usr/share/penguin-assistant/bin/penguin-assistant /usr/bin/penguin-assistant && \
    mkdir -p /etc/penguin-assistant && \
    cp /usr/share/penguin-assistant/config/assistant.conf /etc/penguin-assistant/assistant.conf && \
    cp /usr/share/penguin-assistant/penguin-assistant.desktop /usr/share/applications/penguin-assistant.desktop && \
    mkdir -p /usr/lib/systemd/user/default.target.wants /usr/lib/systemd/user/graphical-session.target.wants && \
    cp /usr/share/penguin-assistant/systemd/penguin-assistant.service /usr/lib/systemd/user/penguin-assistant.service && \
    cp /usr/share/penguin-assistant/systemd/penguin-assistant-overlay.service /usr/lib/systemd/user/penguin-assistant-overlay.service && \
    ln -sf /usr/lib/systemd/user/penguin-assistant.service /usr/lib/systemd/user/default.target.wants/penguin-assistant.service && \
    ln -sf /usr/lib/systemd/user/penguin-assistant-overlay.service /usr/lib/systemd/user/graphical-session.target.wants/penguin-assistant-overlay.service && \
    systemctl enable penguin-update.timer || true && \
    systemctl enable penguin-firstboot-flatpaks.service || true && \
    systemctl enable avahi-daemon.service || true && \
    systemctl enable waydroid-container.service || true


# 12. Apply Custom Plasma Theme, Skel Overlays, SDDM & Environment
COPY ./skel/. /etc/skel/
COPY ./environment/environment /etc/environment
COPY ./environment/xdg/kcm-about-distrorc /etc/xdg/kcm-about-distrorc
COPY ./environment/sddm/10-theme.conf /etc/sddm.conf.d/10-theme.conf
RUN mkdir -p /usr/share/sddm/themes/breeze/
COPY ./environment/sddm/theme.conf.user /usr/share/sddm/themes/breeze/theme.conf.user

# 13. Apply PenguinOS Brand Identity (os-release, logos, wallpapers, boot splash)
COPY ./branding/os-release /usr/lib/os-release
COPY ./branding/os-release /etc/os-release
COPY ./branding/icons/penguinos-logo.svg /usr/share/pixmaps/penguinos-logo.svg
COPY ./branding/icons/penguinos-logo.png /usr/share/pixmaps/penguinos-logo.png
COPY ./branding/icons/penguinos-logo.svg /usr/share/icons/hicolor/scalable/apps/penguinos-logo.svg
COPY ./branding/icons/penguinos-logo.png /usr/share/icons/hicolor/512x512/apps/penguinos-logo.png
COPY ./branding/icons/*.png /usr/share/pixmaps/
COPY ./branding/icons/*.png /usr/share/icons/hicolor/128x128/apps/
COPY ./branding/wallpapers/ /usr/share/wallpapers/

# Brand Start Menu Icons & Fedora Distro Icons to PenguinOS logo
RUN for icon_name in start-here start-here-kde distributor-logo distributor-logo-fedora fedora-logo fedora-logo-icon; do \
        cp -f /usr/share/pixmaps/penguinos-logo.svg /usr/share/icons/hicolor/scalable/apps/${icon_name}.svg 2>/dev/null || true; \
        cp -f /usr/share/pixmaps/penguinos-logo.png /usr/share/icons/hicolor/512x512/apps/${icon_name}.png 2>/dev/null || true; \
        cp -f /usr/share/pixmaps/penguinos-logo.svg /usr/share/pixmaps/${icon_name}.svg 2>/dev/null || true; \
        cp -f /usr/share/pixmaps/penguinos-logo.png /usr/share/pixmaps/${icon_name}.png 2>/dev/null || true; \
    done

# Replace Fedora branding in pixmaps, icons, plymouth boot splash, and anaconda
RUN for d in /usr/share/pixmaps /usr/share/icons /usr/share/plymouth/themes /usr/share/plymouth/themes/spinner /usr/share/plymouth/themes/bgrt /usr/share/plymouth/themes/breeze /usr/share/anaconda/pixmaps; do \
        [ -d "$d" ] || continue; \
        find "$d" -type f \( -name "*fedora*" -o -name "*breeze*logo*" -o -name "watermark.png" -o -name "bgrt-fallback.png" \) | while read -r f; do \
            case "$f" in \
                *.svg) cp -f /usr/share/pixmaps/penguinos-logo.svg "$f" 2>/dev/null || true ;; \
                *.png) cp -f /usr/share/pixmaps/penguinos-logo.png "$f" 2>/dev/null || true ;; \
            esac; \
        done; \
    done

# 13b. Configure Bootloader, GRUB & EFI compatibility for Anaconda / OSTree deployment
COPY ./system/grub/default-grub /etc/default/grub
COPY ./system/boot/bootupd-state.json /boot/bootupd-state.json
COPY ./system/boot/bootupd-state.json /usr/lib/bootupd/bootupd-state.json
COPY ./scripts/grub2-mkconfig-wrapper /usr/local/bin/grub2-mkconfig-wrapper
RUN mkdir -p /boot/efi/EFI /etc/default && \
    ln -sfn fedora /boot/efi/EFI/penguinos && \
    chmod +x /usr/local/bin/grub2-mkconfig-wrapper && \
    if [ -f /usr/sbin/grub2-mkconfig ] && [ ! -f /usr/sbin/grub2-mkconfig.real ]; then \
        mv /usr/sbin/grub2-mkconfig /usr/sbin/grub2-mkconfig.real && \
        cp /usr/local/bin/grub2-mkconfig-wrapper /usr/sbin/grub2-mkconfig && \
        chmod +x /usr/sbin/grub2-mkconfig; \
    fi && \
    if [ -f /usr/bin/grub2-mkconfig ] && [ ! -f /usr/bin/grub2-mkconfig.real ]; then \
        mv /usr/bin/grub2-mkconfig /usr/bin/grub2-mkconfig.real && \
        cp /usr/local/bin/grub2-mkconfig-wrapper /usr/bin/grub2-mkconfig && \
        chmod +x /usr/bin/grub2-mkconfig; \
    fi

# 14. Validate image compliance with bootc
RUN bootc container lint || true

# 15. Clean up packaging cache
RUN ostree container commit
