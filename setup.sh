#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Fedora 44 — Gaming Setup Script                            ║
# ║  Donanım: RX 9070 XT + Ryzen 7 7800X3D + 32GB DDR5         ║
# ║  Kurulum: Hyprland + Noctalia Shell + Full Gaming Stack     ║
# ║  Kullanım: chmod +x setup.sh && ./setup.sh                  ║
# ╚══════════════════════════════════════════════════════════════╝

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
info()    { echo -e "${CYAN}[→]${NC} $1"; }
section() { echo -e "\n${BOLD}${BLUE}══ $1 ══${NC}"; }

check_cpu_arch() {
    section "CPU Mimari Kontrolü"
    if /lib64/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q "x86-64-v3 (supported, searched)"; then
        log "x86-64-v3 destekleniyor — CachyOS kernel kurulabilir ✓"
        SKIP_CACHYOS_KERNEL=false
    else
        warn "x86-64-v3 desteklenmiyor! CachyOS kernel atlanacak."
        SKIP_CACHYOS_KERNEL=true
    fi
}

update_system() {
    section "Sistem Güncelleme"
    sudo dnf update -y || warn "Sistem güncellemesi başarısız."
    sudo dnf install -y git curl wget util-linux-user || warn "Bazı temel araçlar kurulamadı."
    log "Sistem güncellendi."
}

enable_repos() {
    section "Repolar Aktifleştiriliyor"

    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
        || warn "RPM Fusion kurulamadı."
    log "RPM Fusion aktif."

    sudo dnf install -y --nogpgcheck \
        --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
        terra-release || warn "Terra reposu eklenemedi."
    log "Terra reposu aktif."

    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log "Flathub aktif."

    sudo tee /etc/yum.repos.d/google-chrome.repo > /dev/null << 'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
    log "Google Chrome reposu eklendi."
}

setup_amd_rdna4() {
    section "RX 9070 XT — RDNA4 Sürücü & Firmware"

    # Her paket ayrı ayrı kuruluyor — biri olmasa diğerleri etkilenmiyor
    sudo dnf install -y linux-firmware || warn "linux-firmware kurulamadı."
    sudo dnf install -y mesa-vulkan-drivers || warn "mesa-vulkan-drivers kurulamadı."
    sudo dnf install -y mesa-dri-drivers || warn "mesa-dri-drivers kurulamadı."
    sudo dnf install -y mesa-libGL mesa-libEGL mesa-libgbm || warn "Mesa GL/EGL kurulamadı."
    sudo dnf install -y vulkan-loader vulkan-tools || warn "Vulkan loader kurulamadı."
    sudo dnf install -y mesa-libOpenCL || warn "mesa-libOpenCL kurulamadı."

    sudo grubby --update-kernel=ALL \
        --args="amdgpu.ppfeaturemask=0xffffffff amdgpu.modeset=1 amdgpu.dcdebugmask=0x10" \
        || warn "GRUB parametreleri ayarlanamadı."

    sudo tee /etc/modprobe.d/amdgpu-gaming.conf > /dev/null << 'EOF'
options amdgpu ppfeaturemask=0xffffffff
options amdgpu dcdebugmask=0x10
EOF

    sudo tee /etc/udev/rules.d/99-amdgpu-performance.rules > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0x030000", \
    ATTR{power/autosuspend_delay_ms}="-1"
EOF

    sudo tee /etc/environment.d/99-amd-gaming.conf > /dev/null << 'EOF'
RADV_PERFTEST=gpl,sam
AMD_VULKAN_ICD=RADV
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
EOF

    log "RX 9070 XT RDNA4 optimizasyonları uygulandı."
}

install_cachyos_kernel() {
    section "CachyOS Kernel (Ryzen 7 7800X3D Optimize)"

    if [ "${SKIP_CACHYOS_KERNEL:-false}" = "true" ]; then
        warn "CachyOS kernel atlandı."
        return
    fi

    sudo dnf copr enable -y bieszczaders/kernel-cachyos \
        || { warn "CachyOS COPR eklenemedi, atlanıyor."; return; }
    sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons 2>/dev/null || true

    sudo dnf install -y kernel-cachyos kernel-cachyos-devel-matched \
        || { warn "CachyOS kernel bulunamadı, standart kernel kalacak."; return; }

    sudo dnf swap -y zram-generator-defaults cachyos-settings 2>/dev/null \
        || sudo dnf install -y cachyos-settings 2>/dev/null || true

    sudo dnf install -y scx-scheds scx-manager 2>/dev/null || true
    sudo dnf install -y ananicy-cpp cachyos-ananicy-rules 2>/dev/null \
        || sudo dnf install -y ananicy-cpp 2>/dev/null || true

    sudo setsebool -P domain_kernel_load_modules on 2>/dev/null || true

    sudo grubby --update-kernel=ALL \
        --args="amd_pstate=active amd_pstate_epp=performance mitigations=auto" \
        || warn "GRUB parametreleri ayarlanamadı."

    CACHYOS_VMLINUZ=$(ls /boot/vmlinuz-*cachyos* 2>/dev/null | sort -V | tail -1)
    if [ -n "$CACHYOS_VMLINUZ" ]; then
        sudo grubby --set-default="$CACHYOS_VMLINUZ"
        log "CachyOS kernel varsayılan yapıldı."
    fi

    sudo systemctl enable --now ananicy-cpp 2>/dev/null || true
    log "CachyOS kernel kuruldu."
}

install_hyprland() {
    section "Hyprland + Wayland Bileşenleri"

    # Her paket ayrı ayrı — biri olmasa script durmaz
    sudo dnf install -y hyprland || warn "hyprland kurulamadı."
    sudo dnf install -y hyprlock hypridle hyprpaper || warn "hypr araçları kurulamadı."
    sudo dnf install -y xdg-desktop-portal-hyprland xdg-desktop-portal-gtk || warn "xdg-portal kurulamadı."
    sudo dnf install -y xdg-user-dirs || warn "xdg-user-dirs kurulamadı."
    sudo dnf install -y qt6-qtwayland qt5-qtwayland qt6ct || warn "Qt Wayland kurulamadı."
    sudo dnf install -y pipewire pipewire-alsa pipewire-pulseaudio pipewire-jack wireplumber || warn "PipeWire kurulamadı."
    sudo dnf install -y grim slurp wl-clipboard cliphist swappy || warn "Ekran görüntüsü araçları kurulamadı."
    sudo dnf install -y brightnessctl pamixer playerctl || warn "Medya kontrol araçları kurulamadı."
    sudo dnf install -y polkit-gnome network-manager-applet || warn "Polkit/NM kurulamadı."
    sudo dnf install -y blueman udiskie libnotify wayland-utils || warn "Blueman/udiskie kurulamadı."

    log "Hyprland + Wayland stack kuruldu."
}

install_sddm() {
    section "SDDM Display Manager"

    sudo dnf install -y sddm || warn "SDDM kurulamadı."

    if systemctl is-enabled gdm &>/dev/null 2>&1; then
        sudo systemctl disable gdm
        warn "GDM devre dışı bırakıldı."
    fi

    sudo systemctl enable sddm 2>/dev/null || warn "SDDM etkinleştirilemedi."
    log "SDDM ayarlandı."
}

install_noctalia() {
    section "Noctalia Shell"
    sudo dnf install -y noctalia-shell || warn "Noctalia Shell kurulamadı."
    mkdir -p ~/.config/noctalia
    log "Noctalia Shell kuruldu."
}

install_gaming_core() {
    section "Gaming Core — Steam + Wine + Proton"

    sudo dnf install -y steam || warn "Steam kurulamadı."
    sudo dnf install -y wine wine-core wine-common wine-desktop winetricks \
        || warn "Wine kurulamadı."
    sudo dnf install -y lutris || warn "Lutris kurulamadı."
    sudo dnf install -y protontricks 2>/dev/null \
        || pip3 install protontricks --user 2>/dev/null \
        || warn "Protontricks kurulamadı."

    sudo dnf install -y glibc.i686 libstdc++.i686 || warn "32-bit glibc kurulamadı."
    sudo dnf install -y vulkan-loader.i686 || warn "32-bit vulkan-loader kurulamadı."
    sudo dnf install -y alsa-lib.i686 || warn "32-bit alsa kurulamadı."
    sudo dnf install -y SDL2 SDL2.i686 || warn "SDL2 kurulamadı."
    sudo dnf install -y gamemode gamemode.i686 || warn "GameMode kurulamadı."
    sudo dnf install -y mangohud mangohud.i686 || warn "MangoHUD kurulamadı."
    sudo dnf install -y vkd3d vkd3d.i686 || warn "VKD3D kurulamadı."

    systemctl --user enable gamemoded 2>/dev/null || true
    log "Gaming core kuruldu."
}

install_gaming_apps() {
    section "Gaming Uygulamaları (Flatpak)"

    flatpak install -y flathub com.heroicgameslauncher.hgl || warn "Heroic kurulamadı."
    flatpak install -y flathub com.vysp3r.ProtonPlus || warn "ProtonPlus kurulamadı."
    flatpak install -y flathub com.github.tchx84.Flatseal || warn "Flatseal kurulamadı."
    flatpak install -y flathub com.usebottles.bottles || warn "Bottles kurulamadı."
    flatpak install -y flathub com.discordapp.Discord || warn "Discord kurulamadı."

    log "Gaming uygulamaları kuruldu."
}

install_chrome() {
    section "Google Chrome"
    sudo dnf install -y google-chrome-stable || warn "Google Chrome kurulamadı."
    log "Google Chrome kuruldu."
}

install_apps() {
    section "Temel Uygulamalar & Fontlar"

    sudo dnf install -y kitty || warn "kitty kurulamadı."
    sudo dnf install -y thunar thunar-volman gvfs ffmpegthumbnailer tumbler file-roller || warn "Thunar kurulamadı."
    sudo dnf install -y wofi || warn "wofi kurulamadı."
    sudo dnf install -y neovim nano htop btop fastfetch || warn "Terminal araçları kurulamadı."
    sudo dnf install -y noto-fonts noto-fonts-cjk noto-fonts-emoji || warn "Noto fontlar kurulamadı."
    sudo dnf install -y jetbrains-mono-fonts fira-code-fonts || warn "Programlama fontları kurulamadı."
    sudo dnf install -y papirus-icon-theme || warn "Papirus ikonları kurulamadı."
    sudo dnf install -y ffmpeg || warn "ffmpeg kurulamadı."
    sudo dnf install -y p7zip unrar || warn "Arşiv araçları kurulamadı."
    sudo dnf install -y pavucontrol || warn "pavucontrol kurulamadı."

    log "Temel uygulamalar kuruldu."
}

setup_hyprland_config() {
    section "Hyprland Yapılandırması"
    mkdir -p ~/.config/hypr

    cat > ~/.config/hypr/hyprland.conf << 'HYPRCONF'
monitor=,preferred,auto,1

exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = qs -c noctalia-shell
exec-once = hyprpaper
exec-once = hypridle
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = udiskie -t
exec-once = wl-paste --watch cliphist store

env = XCURSOR_SIZE,24
env = XCURSOR_THEME,Adwaita
env = QT_QPA_PLATFORM,wayland
env = QT_QPA_PLATFORMTHEME,qt6ct
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1
env = ELECTRON_OZONE_PLATFORM_HINT,wayland
env = AMD_VULKAN_ICD,RADV
env = VK_ICD_FILENAMES,/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
env = RADV_PERFTEST,gpl,sam
env = STEAM_FORCE_DESKTOPUI_SCALING,1

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(7aa2f7ff) rgba(bb9af7ff) 45deg
    col.inactive_border = rgba(1a1b26aa)
    layout = dwindle
}

decoration {
    rounding = 12
    blur {
        enabled = true
        size = 6
        passes = 3
        new_optimizations = true
    }
    shadow {
        enabled = true
        range = 15
        render_power = 3
        color = rgba(1a1a2ecc)
    }
    inactive_opacity = 0.92
}

animations {
    enabled = true
    bezier = smooth, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, smooth
    animation = windowsOut, 1, 7, default, popin 80%
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    vfr = true
}

input {
    kb_layout = tr
    follow_mouse = 1
    sensitivity = 0
}

$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive
bind = $mainMod SHIFT, M, exit
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating
bind = $mainMod, D, exec, qs -c noctalia-shell ipc call launcher toggle
bind = $mainMod, F, fullscreen
bind = $mainMod SHIFT, S, exec, grim -g "$(slurp)" - | swappy -f -
bind = $mainMod, N, exec, qs -c noctalia-shell ipc call controlCenter toggle
bind = $mainMod SHIFT, L, exec, qs -c noctalia-shell ipc call lockScreen lock
bind = $mainMod, G, exec, steam -gamepadui

bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

bindel = ,XF86AudioRaiseVolume, exec, pamixer -i 5
bindel = ,XF86AudioLowerVolume, exec, pamixer -d 5
bindl = ,XF86AudioMute, exec, pamixer -t
bindl = ,XF86AudioPlay, exec, playerctl play-pause
bindl = ,XF86AudioNext, exec, playerctl next
bindl = ,XF86AudioPrev, exec, playerctl previous
bindel = ,XF86MonBrightnessUp, exec, brightnessctl set +5%
bindel = ,XF86MonBrightnessDown, exec, brightnessctl set 5%-

windowrulev2 = fullscreen, class:^(steam_app_.*)$
windowrulev2 = immediate, class:^(steam_app_.*)$
windowrulev2 = float, class:^(steam)$, title:^(Steam - News.*)$
windowrulev2 = float, class:^(lutris)$
windowrulev2 = float, class:^(heroic)$
HYPRCONF

    log "hyprland.conf oluşturuldu."
}

setup_steam_optimizations() {
    section "Steam Gaming Optimizasyonları"
    mkdir -p ~/.config/steam ~/.local/share/Steam/config

    cat > ~/STEAM_LAUNCH_OPTIONS.txt << 'EOF'
# Tam önerilen:
RADV_PERFTEST=gpl,sam AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

# Sadece GameMode:
gamemoderun %command%

# Sadece MangoHUD:
mangohud %command%

# Saf Vulkan:
RADV_PERFTEST=gpl,sam AMD_VULKAN_ICD=RADV %command%
EOF

    log "Steam optimizasyon şablonu ~/STEAM_LAUNCH_OPTIONS.txt kaydedildi."
}

setup_wallpaper() {
    mkdir -p ~/Pictures/Wallpapers ~/.config/hypr
    curl -sL "https://raw.githubusercontent.com/JaKooLit/Wallpaper-Bank/main/wallpapers/dark-colorful-leaves.jpg" \
        -o ~/Pictures/Wallpapers/default.jpg 2>/dev/null || true

    cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = ~/Pictures/Wallpapers/default.jpg
wallpaper = ,~/Pictures/Wallpapers/default.jpg
splash = false
EOF
}

setup_shell() {
    section "Shell & XDG Ayarları"
    xdg-user-dirs-update
    sudo dnf install -y zsh || warn "ZSH kurulamadı."
    sudo chsh -s /bin/zsh "$USER"
    if [ ! -d ~/.oh-my-zsh ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
            || warn "Oh-My-ZSH kurulamadı."
    fi
    log "ZSH ayarlandı."
}

main() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║   Fedora 44 Gaming Setup                                     ║"
    echo "║   RX 9070 XT  ·  Ryzen 7 7800X3D  ·  32GB DDR5             ║"
    echo "║   Hyprland + Noctalia Shell + Full Gaming Stack              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sleep 2

    check_cpu_arch
    update_system
    enable_repos
    setup_amd_rdna4
    install_cachyos_kernel
    install_hyprland
    install_sddm
    install_noctalia
    install_gaming_core
    install_gaming_apps
    install_chrome
    install_apps
    setup_hyprland_config
    setup_steam_optimizations
    setup_wallpaper
    setup_shell

    echo ""
    echo -e "${BOLD}${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅  KURULUM TAMAMLANDI!                                      ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  → sudo reboot ile yeniden başlatın                         ║"
    echo "║  → SDDM'de Hyprland oturumunu seçin                        ║"
    echo "║                                                              ║"
    echo "║  Kısayollar:                                                 ║"
    echo "║    Super+Enter  → Terminal        Super+D → Launcher        ║"
    echo "║    Super+N      → Kontrol Merkezi Super+G → Steam           ║"
    echo "║    Super+Shift+L → Ekran Kilidi                              ║"
    echo "║                                                              ║"
    echo "║  İlk açılışta:                                               ║"
    echo "║    1. ProtonPlus → Proton-GE indir                          ║"
    echo "║    2. Steam → Ayarlar → Uyumluluk → Proton-GE seç          ║"
    echo "║    3. ~/STEAM_LAUNCH_OPTIONS.txt incele                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

main "$@"
