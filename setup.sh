#!/bin/bash

echo "=== Rozpoczynanie uniwersalnego skryptu poinstalacyjnego ==="

# --- Wykrywanie środowiska graficznego ---
if echo "$XDG_CURRENT_DESKTOP" | grep -iq "GNOME"; then
    DE="GNOME"
    echo "Wykryto środowisko: GNOME"
elif echo "$XDG_CURRENT_DESKTOP" | grep -iq "KDE"; then
    DE="KDE"
    echo "Wykryto środowisko: KDE Plasma"
else
    echo "Nie udało się jednoznacznie wykryć GNOME ani KDE (XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP)."
    read -p "Naciśnij Enter, aby kontynuować, lub Ctrl+C, aby przerwać..."
fi

# ------------------------------------------------------------
# 1. INSTALACJA NARZĘDZI PODSTAWOWYCH (git, base-devel itp.)
# ------------------------------------------------------------
echo "Instaluję podstawowe narzędzia (git, base-devel, itp.)..."
sudo pacman -S --needed base-devel git wget cmake flatpak ntfs-3g unzip --noconfirm

# ------------------------------------------------------------
# 2. KONFIGURACJA LOKALNEGO REPOZYTORIUM LINEXIN
# ------------------------------------------------------------
echo "Pobieram i konfiguruję linexin-repo jako lokalne repozytorium..."
sudo mkdir -p /opt
if [ ! -d "/opt/linexin-repo" ]; then
    sudo git clone https://github.com/Petexy/linexin-repo.git /opt/linexin-repo
else
    cd /opt/linexin-repo && sudo git pull && cd -
fi

# Sprawdzenie czy repozytorium zawiera bazę pacmana (opcjonalne ostrzeżenie)
if [ ! -f "/opt/linexin-repo/x86_64/linexin-repo.db.tar.gz" ]; then
    echo "UWAGA: Brak pliku bazy danych w /opt/linexin-repo/x86_64."
    echo "Jeśli repozytorium zawiera tylko PKGBUILD, musisz je najpierw zbudować."
    echo "Możesz pominąć to ostrzeżenie, jeśli używasz innej metody."
fi

# Dodanie wpisu do pacman.conf, jeśli jeszcze nie istnieje
if ! grep -q "\[linexin-repo\]" /etc/pacman.conf; then
    echo -e "\n[linexin-repo]\nSigLevel = Optional TrustAll\nServer = file:///opt/linexin-repo/x86_64" | sudo tee -a /etc/pacman.conf
fi

# Aktualizacja listy pakietów (bez aktualizacji całego systemu)
sudo pacman -Sy --noconfirm

# ------------------------------------------------------------
# 3. INSTALACJA YAY (AUR helper)
# ------------------------------------------------------------
if ! command -v yay &> /dev/null; then
    echo "Buduję yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi

# ------------------------------------------------------------
# 4. INSTALACJA PROGRAMÓW SYSTEMOWYCH ZALEŻNYCH OD ŚRODOWISKA
# ------------------------------------------------------------
if [ "$DE" = "GNOME" ]; then
    echo "Instaluję pakiety dla GNOME (Wirtualizacja, Zsh, Fastfetch i przykładowe rozszerzenia)..."
    sudo pacman -S --noconfirm \
        zsh \
        fastfetch \
        gnome-tweaks \
        extension-manager \
        bibata-cursor-theme-bin \
        starship \
        ttf-jetbrains-mono-nerd \
        maven \
        jdk-openjdk \
        pacman-contrib \
        btop \
        virt-manager \
        qemu-desktop \
        libvirt \
        edk2-ovmf \
        dnsmasq \
        iptables-nft \
        bridge-utils \
        openbsd-netcat \
        lutris \
        # Przykładowe rozszerzenia GNOME (z oficjalnych repozytoriów)
        gnome-shell-extension-dash-to-dock \
        gnome-shell-extension-blur-my-shell \
        gnome-shell-extension-appindicator

elif [ "$DE" = "KDE" ]; then
    echo "Instaluję pakiety dla KDE Plasma (Wirtualizacja, Zsh i Fastfetch)..."
    sudo pacman -S --noconfirm \
        zsh \
        fastfetch \
        starship \
        ttf-jetbrains-mono-nerd \
        ttf-inter \
        maven \
        jdk-openjdk \
        bibata-cursor-theme-bin \
        kvantum-qt5 \
        kvantum-qt6 \
        ark \
        konsole \
        dolphin \
        virt-manager \
        qemu-desktop \
        libvirt \
        edk2-ovmf \
        dnsmasq \
        iptables-nft \
        bridge-utils \
        openbsd-netcat \
        lutris
fi

# ------------------------------------------------------------
# 5. APLIKACJE FLATPAK
# ------------------------------------------------------------
echo "Konfiguruję Flathub i instaluję aplikacje..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub -y \
    com.discordapp.Discord \
    com.valvesoftware.Steam \
    org.mozilla.firefox \
    io.github.zen_browser.zen \
    com.usebottles.bottles

# ------------------------------------------------------------
# 6. INSTALACJA CZCIONEK, MOTYWÓW I DODATKOWYCH APLIKACJI Z AUR / LINEXIN
# ------------------------------------------------------------
echo "Instaluję czcionkę Poppins oraz Faugus Launcher..."
yay -S --noconfirm ttf-poppins faugus-launcher

if [ "$DE" = "GNOME" ]; then
    echo "Instaluję motyw i ikony Colloid..."
    cd /tmp
    git clone https://github.com/vinceliuice/Colloid-gtk-theme.git
    ./Colloid-gtk-theme/install.sh -t purple -s standard
    rm -rf Colloid-gtk-theme

    git clone https://github.com/vinceliuice/Colloid-icon-theme.git
    ./Colloid-icon-theme/install.sh -t purple
    rm -rf Colloid-icon-theme

elif [ "$DE" = "KDE" ]; then
    echo "Instaluję paczki wizualne dla KDE..."
    yay -S --noconfirm \
        whitesur-kde-theme-git \
        whitesur-icon-theme-git \
        klassy-git \
        plasma6-applets-panel-colorizer \
        plasma6-applets-window-title \
        plasma6-applets-window-buttons

    echo "Instaluję motyw Layan dla KDE..."
    cd /tmp
    git clone https://github.com/vinceliuice/Layan-kde.git
    cd Layan-kde
    ./install.sh
    cd ..
    rm -rf Layan-kde

    echo ">>> Instalacja efektu Better Blur DX (wymaga sudo)..."
    cd /tmp
    git clone https://github.com/xarblu/kwin-effects-better-blur-dx
    cd kwin-effects-better-blur-dx
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr
    make -j$(nproc)
    sudo make install
    cd /tmp
    rm -rf kwin-effects-better-blur-dx

    echo ">>> Instalacja efektu Rounded Corners (Wayland)..."
    yay -S --noconfirm kwin-effect-rounded-corners-git
fi

# ------------------------------------------------------------
# 7. KONFIGURACJA rEFInd
# ------------------------------------------------------------
if [ -d "/boot/EFI/refind" ]; then
    echo "Konfiguruję rEFInd..."

    ROOT_UUID="80cae5af-59e1-4176-9e2d-40232d3ea04d"
    PARAMS="rw root=UUID=$ROOT_UUID nvidia-drm.modeset=1 video=HDMI-A-1:d"

    UCODE="initrd=\\intel-ucode.img"
    if grep -q "AMD" /proc/cpuinfo; then
        UCODE="initrd=\\amd-ucode.img"
    fi

    sudo tee /boot/EFI/refind/refind_linux.conf <<EOF
"Standard Boot"  "$PARAMS $UCODE initrd=\\initramfs-linux.img"
"Terminal Boot"  "$PARAMS $UCODE initrd=\\initramfs-linux.img systemd.unit=multi-user.target"
EOF
    echo "rEFInd skonfigurowany pomyślnie."
fi

# ------------------------------------------------------------
# 8. DYSK NTFS i STEAM FIX
# ------------------------------------------------------------
if lsblk -dno LABEL | grep -q "nowy"; then
    echo "Konfiguruję dysk NTFS 'nowy' i dowiązania dla Steam..."
    sudo mkdir -p /mnt/nowy
    if ! grep -q "/mnt/nowy" /etc/fstab; then
        echo "LABEL=nowy /mnt/nowy ntfs-3g defaults,nosuid,nodev,nofail,uid=$(id -u),gid=$(id -g),dmask=022,fmask=133,windows_names 0 0" | sudo tee -a /etc/fstab
    fi
    sudo mount -a
    mkdir -p ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/
    mkdir -p ~/.steam_compat_fix
    ln -sf ~/.steam_compat_fix ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata
fi

# ------------------------------------------------------------
# 9. KONFIGURACJA WIRTUALIZACJI (virt-manager) I SIECI BRIDGE
# ------------------------------------------------------------
echo "Konfiguruję usługi systemd i grupy dla wirtualizacji..."
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

sudo usermod -aG libvirt $USER

if [ -f /etc/libvirt/qemu/networks/default.xml ]; then
    sudo virsh net-define /etc/libvirt/qemu/networks/default.xml 2>/dev/null || true
    sudo virsh net-autostart default 2>/dev/null || true
    sudo virsh net-start default 2>/dev/null || true
fi

MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
if [ -n "$MAIN_IF" ]; then
    echo "Dodaję sieć Bridge (Macvtap) do libvirt pod interfejs $MAIN_IF..."
    cat <<EOF > /tmp/host-bridge.xml
<network>
  <name>host-bridge</name>
  <forward mode="bridge">
    <interface dev="$MAIN_IF"/>
  </forward>
</network>
EOF
    sudo virsh net-define /tmp/host-bridge.xml 2>/dev/null || true
    sudo virsh net-autostart host-bridge 2>/dev/null || true
    sudo virsh net-start host-bridge 2>/dev/null || true
    rm -f /tmp/host-bridge.xml
fi

# ------------------------------------------------------------
# 10. KONFIGURACJA ZSH, STARSHIP I FASTFETCH
# ------------------------------------------------------------
echo "Konfiguruję Zsh, Starship i Fastfetch..."
echo 'eval "$(starship init zsh)"' > ~/.zshrc
echo 'fastfetch' >> ~/.zshrc
chsh -s /usr/bin/zsh $USER

# ------------------------------------------------------------
# 11. FINALIZACJA WYGLĄDU (Kursor, Ikony, Czcionki, Tapeta)
# ------------------------------------------------------------
echo "Ustawiam kursor Bibata Classic Black oraz domyślne opcje wyglądu..."

if [ "$DE" = "GNOME" ]; then
    gsettings set org.gnome.desktop.interface icon-theme 'Colloid-purple'
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Classic-Black'

    # Ustawianie czcionki Poppins dla interfejsu
    gsettings set org.gnome.desktop.interface font-name 'Poppins 10'
    gsettings set org.gnome.desktop.interface document-font-name 'Poppins 10'

    # Pobieranie i ustawianie tapety
    URL_TAPETY="https://i.imgur.com/Y9X3VQz.jpeg"
    NAZWA_PLIKU="tapeta_arch.jpg"
    mkdir -p ~/Pobrane ~/Obrazy
    curl -L "$URL_TAPETY" -o ~/Pobrane/$NAZWA_PLIKU
    cp ~/Pobrane/$NAZWA_PLIKU ~/Obrazy/$NAZWA_PLIKU
    SCIEZKA_FINALNA="$HOME/Obrazy/$NAZWA_PLIKU"

    gsettings set org.gnome.desktop.background picture-uri "file://$SCIEZKA_FINALNA"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$SCIEZKA_FINALNA"
    gsettings set org.gnome.desktop.background picture-options 'zoom'

elif [ "$DE" = "KDE" ]; then
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "Bibata-Classic-Black"
    /usr/bin/kcminit kcm_cursortheme
fi

# ------------------------------------------------------------
# 12. ZAKOŃCZENIE
# ------------------------------------------------------------
echo "=== KONIEC SKRYPTU ==="
echo "System zostanie uruchomiony ponownie za 5 sekund..."
sleep 5
reboot
