#!/bin/bash

# Skrypt poinstalacyjny dla KDE Plasma
# Uruchom z uprawnieniami użytkownika (sudo będzie używane gdzie potrzebne)

set -e  # zatrzymaj przy błędzie

echo "=== Rozpoczynam skrypt poinstalacyjny dla KDE Plasma ==="

# Sprawdzenie czy to KDE
if ! echo "$XDG_CURRENT_DESKTOP" | grep -iq "KDE"; then
    echo "To nie jest środowisko KDE Plasma. Skrypt przeznaczony tylko dla KDE."
    exit 1
fi

# ------------------------------------------------------------
# 1. NAPRAWA MIRRORÓW I AKTUALIZACJA
# ------------------------------------------------------------
echo "Aktualizuję serwery i bazę pakietów..."
sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman -Syu --noconfirm

# ------------------------------------------------------------
# 2. INSTALACJA NARZĘDZI BUDOWANIA I PODSTAW
# ------------------------------------------------------------
echo "Instaluję base-devel, git i podstawowe narzędzia..."
sudo pacman -S --needed base-devel git wget cmake flatpak ntfs-3g unzip --noconfirm

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
# 4. INSTALACJA PROGRAMÓW Z REPOZYTORIÓW
# ------------------------------------------------------------
echo "Instaluję podstawowe programy z oficjalnych repozytoriów..."
sudo pacman -S --noconfirm \
    fish \
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
    lutris \
    pacman-contrib \
    btop

# ------------------------------------------------------------
# 5. APLIKACJE FLATPAK (takie same jak w GNOME)
# ------------------------------------------------------------
echo "Konfiguruję Flathub i instaluję aplikacje Flatpak..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub -y \
    com.discordapp.Discord \
    com.valvesoftware.Steam \
    org.mozilla.firefox \
    io.github.zen_browser.zen \
    com.usebottles.bottles

# ------------------------------------------------------------
# 6. INSTALACJA MOTYWU LAYAN DLA KDE
# ------------------------------------------------------------
echo "Instaluję motyw Layan dla KDE..."
cd /tmp
git clone https://github.com/vinceliuice/Layan-kde.git
cd Layan-kde
./install.sh
cd ..
rm -rf Layan-kde

# ------------------------------------------------------------
# 7. INSTALACJA DODATKOWYCH MOTYWÓW I APLETÓW Z AUR
# ------------------------------------------------------------
echo "Instaluję dodatkowe pakiety wizualne z AUR..."
yay -S --noconfirm \
    whitesur-kde-theme-git \
    whitesur-icon-theme-git \
    klassy-git \
    plasma6-applets-panel-colorizer \
    plasma6-applets-window-title \
    plasma6-applets-window-buttons \
    ttf-poppins \
    faugus-launcher

# ------------------------------------------------------------
# 8. INSTALACJA EFEKTÓW KWIN
# ------------------------------------------------------------
echo "Instaluję efekty KWin..."

# Better Blur (forceblur) - zgodnie z dokumentacją z AUR
yay -S --noconfirm kwin-effects-forceblur

# Rounded Corners
yay -S --noconfirm kwin-effect-rounded-corners-git

echo "✓ Efekty KWin zainstalowane."
echo "⚠️  Aby je włączyć, otwórz Ustawienia Systemowe → Efekty pulpitu,"
echo "   wyłącz domyślny efekt rozmycia i włącz 'Better Blur' oraz 'Rounded Corners'."

# ------------------------------------------------------------
# 9. KONFIGURACJA KVANTUM
# ------------------------------------------------------------
echo "Konfiguruję Kvantum..."
mkdir -p ~/.config/Kvantum
cat > ~/.config/Kvantum/kvantum.kvconfig <<EOF
[General]
theme=Layan
EOF
echo "✓ Kvantum skonfigurowany z motywem Layan (wymaga ręcznego wyboru w aplikacji)."

# ------------------------------------------------------------
# 10. KONFIGURACJA rEFInd (opcjonalnie)
# ------------------------------------------------------------
if [ -d "/boot/EFI/refind" ]; then
    CURRENT_ROOT_UUID=$(findmnt -n -o UUID /)
    echo "Konfiguruję rEFInd dla UUID: $CURRENT_ROOT_UUID"
    
    PARAMS="rw root=UUID=$CURRENT_ROOT_UUID video=HDMI-A-1:d"
    lspci | grep -iq "nvidia" && PARAMS="$PARAMS nvidia-drm.modeset=1"
    
    # Wykrywanie Microcode
    UCODE="initrd=\\intel-ucode.img"
    grep -q "AMD" /proc/cpuinfo && UCODE="initrd=\\amd-ucode.img"

    sudo tee /boot/EFI/refind/refind_linux.conf <<EOF
"Standard Boot"  "$PARAMS $UCODE initrd=\\initramfs-linux.img"
"Terminal Boot"  "$PARAMS $UCODE initrd=\\initramfs-linux.img systemd.unit=multi-user.target"
EOF
    echo "✓ rEFInd skonfigurowany"
fi

# ------------------------------------------------------------
# 11. DYSK NTFS i STEAM FIX
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
    echo "✓ Dysk 'nowy' skonfigurowany"
fi

# ------------------------------------------------------------
# 12. KONFIGURACJA WIRTUALIZACJI (libvirt)
# ------------------------------------------------------------
echo "Konfiguruję usługi systemd i grupy dla wirtualizacji..."

# Załadowanie modułów jądra
sudo modprobe bridge 2>/dev/null || echo "Moduł bridge już załadowany"
sudo modprobe br_netfilter 2>/dev/null || echo "Moduł br_netfilter już załadowany"

# Automatyczne ładowanie modułów przy starcie
echo "bridge" | sudo tee /etc/modules-load.d/virt-network.conf
echo "br_netfilter" | sudo tee -a /etc/modules-load.d/virt-network.conf

# Włączenie i uruchomienie libvirtd
if systemctl list-unit-files | grep -q libvirtd.service; then
    sudo systemctl enable libvirtd.service
    sudo systemctl start libvirtd.service
    echo "✓ Usługa libvirtd uruchomiona"
else
    echo "⚠ Usługa libvirtd nie została znaleziona"
fi

# Dodanie użytkownika do grupy libvirt
sudo usermod -aG libvirt $USER
echo "✓ Użytkownik $USER dodany do grupy libvirt"

# Definiowanie domyślnej sieci NAT
if [ -f /etc/libvirt/qemu/networks/default.xml ]; then
    sudo virsh net-define /etc/libvirt/qemu/networks/default.xml 2>/dev/null || true
    sudo virsh net-autostart default 2>/dev/null || true
    sudo virsh net-start default 2>/dev/null || true
fi

# Definiowanie sieci mostkowanej (macvtap) dla głównego interfejsu
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
if [ -n "$MAIN_IF" ]; then
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
    echo "✓ Sieć mostkowana skonfigurowana"
fi

# ------------------------------------------------------------
# 13. KONFIGURACJA POWŁOKI (Fish + Starship)
# ------------------------------------------------------------
echo "Konfiguruję Starship dla Fish..."
mkdir -p ~/.config/fish
echo 'starship init fish | source' > ~/.config/fish/config.fish
echo 'fastfetch' >> ~/.config/fish/config.fish

echo "Zmieniam domyślną powłokę na Fish..."
chsh -s /usr/bin/fish $USER

# ------------------------------------------------------------
# 14. USTAWIENIA WYGLĄDU (Kursor, Motyw, Tapeta)
# ------------------------------------------------------------
echo "Stosuję ustawienia wyglądu..."

# Ustaw kursor Bibata
kwriteconfig6 --file ~/.config/kcminputrc --group Mouse --key cursorTheme "Bibata-Classic-Black"
echo "✓ Kursor ustawiony na Bibata-Classic-Black (po restarcie KDE)"

# Pobierz i ustaw tapetę (ta sama co w GNOME)
URL_TAPETY="https://i.imgur.com/Y9X3VQz.jpeg"
NAZWA_PLIKU="tapeta_arch.jpg"
mkdir -p ~/Pobrane ~/Obrazy
curl -L "$URL_TAPETY" -o ~/Pobrane/$NAZWA_PLIKU 2>/dev/null
cp ~/Pobrane/$NAZWA_PLIKU ~/Obrazy/$NAZWA_PLIKU 2>/dev/null
SCIEZKA_FINALNA="$HOME/Obrazy/$NAZWA_PLIKU"

if [ -f "$SCIEZKA_FINALNA" ]; then
    # Ustaw tapetę w KDE (działa dla Plasma 6)
    kwriteconfig6 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group Wallpaper --group org.kde.image --group General --key Image "file://$SCIEZKA_FINALNA"
    echo "✓ Tapeta ustawiona (wymaga restartu Plasma)"
fi

# ------------------------------------------------------------
# 15. KONIEC
# ------------------------------------------------------------
echo ""
echo "====================================================="
echo "=== SKRYPT ZAKOŃCZONY POMYŚLNIE ==="
echo "====================================================="
echo ""
echo "✅ Wykonano:"
echo "  - Aktualizacja systemu"
echo "  - Instalacja narzędzi (git, base-devel, yay)"
echo "  - Instalacja programów z oficjalnych repozytoriów"
echo "  - Instalacja aplikacji Flatpak (Discord, Steam, Firefox, Zen, Bottles)"
echo "  - Instalacja motywu Layan dla KDE"
echo "  - Instalacja efektów KWin: forceblur i rounded corners"
echo "  - Konfiguracja Kvantum z motywem Layan"
echo "  - Konfiguracja rEFInd (jeśli wykryto)"
echo "  - Konfiguracja dysku NTFS i Steam"
echo "  - Konfiguracja wirtualizacji (libvirt)"
echo "  - Ustawienie powłoki Fish ze Starship"
echo "  - Ustawienie kursora Bibata i tapety"
echo ""
echo "⚠️  UWAGI KOŃCOWE:"
echo "  1. Aby zmiany w grupach (libvirt) zadziałały, wyloguj się i zaloguj ponownie."
echo "  2. Efekty KWin wymagają ręcznego włączenia:"
echo "     → Ustawienia Systemowe → Efekty pulpitu"
echo "     → Wyłącz domyślny efekt rozmycia"
echo "     → Włącz 'Better Blur' i 'Rounded Corners'"
echo "  3. Motyw Layan i kursor Bibata będą widoczne po restarcie Plasma."
echo "  4. Kvantum: uruchom 'kvantummanager' i wybierz motyw 'Layan'."
echo ""
echo "🔁 System zrestartuje się za 10 sekund..."
echo "Naciśnij Ctrl+C, aby anulować restart."

sleep 10
sudo reboot
