#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Fedora 44 — Gaming Setup Script                            ║
# ║  Donanım: RX 9070 XT + Ryzen 7 7800X3D + 32GB DDR5         ║
# ║  Kurulum: Hyprland + Noctalia Shell + Full Gaming Stack     ║
# ║  Kullanım: chmod +x setup.sh && ./setup.sh                  ║
# ╚══════════════════════════════════════════════════════════════╝

# set -e kaldırıldı — opsiyonel paketlerde script durmasın
# Kritik adımlar elle kontrol ediliyor

# ── Renkler & Loglama ─────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
info()    { echo -e "${CYAN}[→]${NC} $1"; }
section() { echo -e "\n${BOLD}${BLUE}══ $1 ══${NC}"; }
err()     { echo -e "${RED}[✗] HATA: $1${NC}"; exit 1; }

# ── x86-64-v3 desteği kontrolü (CachyOS kernel için zorunlu) ──
check_cpu_arch() {
    section "CPU Mimari Kontrolü"
    if /lib64/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q "x86-64-v3 (supported, searched)"; then
        log "x86-64-v3 destekleniyor — CachyOS kernel kurulabilir ✓"
        SKIP_CACHYOS_KERNEL=false
    else
        warn "x86-64-v3 desteklenmiyor! CachyOS kernel kurulmayacak, standart Fedora kernel kalacak."
        SKIP_CACHYOS_KERNEL=true
    fi
}

# ─────────────────────────────────────────────────────────────
# 1. SİSTEM GÜNCELLEMESİ
# ─────────────────────────────────────────────────────────────
update_system() {
    section "Sistem Güncelleme"
    sudo dnf update -y || err "Sistem güncellemesi başarısız oldu."
    sudo dnf install -y git curl wget util-linux-user || err "Temel araçlar kurulamadı."
    log "Sistem güncellendi."
}

# ─────────────────────────────────────────────────────────────
# 2. REPOLAR: RPM Fusion + Terra + Flathub + Chrome
# ─────────────────────────────────────────────────────────────
enable_repos() {
    section "Repolar Aktifleştiriliyor"

    # RPM Fusion Free + Nonfree
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
        || err "RPM Fusion kurulamadı."
    log "RPM Fusion aktif."

    # Terra (Noctalia Shell için)
    sudo dnf install -y --nogpgcheck \
        --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
        terra-release || warn "Terra reposu eklenemedi, Noctalia kurulumu başarısız olabilir."
    log "Terra reposu aktif."

    # Flathub
    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log "Flathub aktif."

    # Google Chrome repo
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

# ─────────────────────────────────────────────────────────────
# 3. RX 9070 XT — RDNA4 AMD SÜRÜCÜ & OPTİMİZASYON
# ─────────────────────────────────────────────────────────────
setup_amd_rdna4() {
    section "RX 9070 XT — RDNA4 Sürücü & Firmware"

    # En güncel firmware ve Mesa (RDNA4 için kritik)
    sudo dnf install -y \
        linux-firmware \
        mesa-vulkan-drivers \
        mesa-dri-drivers \
        mesa-libGL \
        mesa-libEGL \
        mesa-libgbm \
        vulkan-loader \
        vulkan-tools \
        mesa-vdpau \
        mesa-libOpenCL \
        || err "AMD sürücü paketleri kurulamadı."

    # GRUB kernel parametreleri
    # ppfeaturemask=0xffffffff → undervolting dahil tüm güç yönetimi açık
    # amdgpu.modeset=1        → RDNA4 siyah ekran sorununu önler
    # amdgpu.dcdebugmask=0x10 → display engine hata ayıklama maskesi
    sudo grubby --update-kernel=ALL \
        --args="amdgpu.ppfeaturemask=0xffffffff amdgpu.modeset=1 amdgpu.dcdebugmask=0x10"

    # modprobe ayarları
    sudo tee /etc/modprobe.d/amdgpu-gaming.conf > /dev/null << 'EOF'
# RX 9070 XT RDNA4 performans ayarları
options amdgpu ppfeaturemask=0xffffffff
options amdgpu dcdebugmask=0x10
EOF

    # udev: GPU güç yönetimi auto-suspend'i kapat (oyun sırasında gecikme önlenir)
    sudo tee /etc/udev/rules.d/99-amdgpu-performance.rules > /dev/null << 'EOF'
# RX 9070 XT için GPU güç profili — auto-suspend devre dışı
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0x030000", \
    ATTR{power/autosuspend_delay_ms}="-1"
EOF

    # Sistem geneli AMD/Vulkan ortam değişkenleri
    # NOT: RADV_DEBUG=nocompute KALDIRILDI — async compute'u kapatırdı, performans düşerdi
    # NOT: MESA_LOADER_DRIVER_OVERRIDE KALDIRILDI — Wayland'da zaten radeonsi geliyor
    sudo tee /etc/environment.d/99-amd-gaming.conf > /dev/null << 'EOF'
# RDNA4 / RX 9070 XT Vulkan & performans ayarları
RADV_PERFTEST=gpl,sam
AMD_VULKAN_ICD=RADV
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
EOF

    log "RX 9070 XT RDNA4 sürücü optimizasyonları uygulandı."
    warn "RDNA4 için kritik: linux-firmware her zaman güncel tutun (sudo dnf update)."
}

# ─────────────────────────────────────────────────────────────
# 4. CACHYOSKERNELi — Ryzen 7 7800X3D Optimize
# ─────────────────────────────────────────────────────────────
install_cachyos_kernel() {
    section "CachyOS Kernel (Ryzen 7 7800X3D Optimize)"

    if [ "${SKIP_CACHYOS_KERNEL:-false}" = "true" ]; then
        warn "CachyOS kernel atlandı (x86-64-v3 desteği yok)."
        return
    fi

    # COPR repolarını ekle
    sudo dnf copr enable -y bieszczaders/kernel-cachyos \
        || { warn "CachyOS kernel COPR reposu eklenemedi (fc44 için henüz build olmayabilir). Atlanıyor."; return; }
    sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons 2>/dev/null || true

    # Kernel kur — GCC build (gaming için önerilen)
    # İçerir: BORE scheduler, AMD P-State Preferred Core, x86-64-v3 optimizasyonu
    sudo dnf install -y kernel-cachyos kernel-cachyos-devel-matched \
        || { warn "CachyOS kernel paketi bulunamadı. Standart Fedora kernel kalacak."; return; }

    # CachyOS sistem ayarları (gaming tweaks)
    sudo dnf swap -y zram-generator-defaults cachyos-settings 2>/dev/null \
        || sudo dnf install -y cachyos-settings 2>/dev/null || true

    # sched-ext scheduler (gaming profili)
    sudo dnf install -y scx-scheds scx-manager 2>/dev/null || true

    # ananicy-cpp: process öncelik yöneticisi
    sudo dnf install -y ananicy-cpp cachyos-ananicy-rules 2>/dev/null \
        || sudo dnf install -y ananicy-cpp 2>/dev/null || true

    # SELinux: kernel modül yüklemeye izin ver
    sudo setsebool -P domain_kernel_load_modules on 2>/dev/null || true

    # AMD P-State + güvenli azaltımlar
    sudo grubby --update-kernel=ALL \
        --args="amd_pstate=active amd_pstate_epp=performance mitigations=auto"

    # CachyOS kernelini varsayılan yap
    CACHYOS_VMLINUZ=$(ls /boot/vmlinuz-*cachyos* 2>/dev/null | sort -V | tail -1)
    if [ -n "$CACHYOS_VMLINUZ" ]; then
        sudo grubby --set-default="$CACHYOS_VMLINUZ"
        log "CachyOS kernel varsayılan yapıldı: $CACHYOS_VMLINUZ"
    fi

    # ananicy-cpp servisini etkinleştir
    sudo systemctl enable --now ananicy-cpp 2>/dev/null || true

    log "CachyOS kernel kuruldu. BORE scheduler + AMD P-State Preferred Core aktif."
    info "Ryzen 7 7800X3D — 3D V-Cache optimizasyonu kernel seviyesinde aktif."
}

# ─────────────────────────────────────────────────────────────
# 5. HYPRLAND + WAYLAND STACK
# ─────────────────────────────────────────────────────────────
install_hyprland() {
    section "Hyprland + Wayland Bileşenleri"

    sudo dnf install -y \
        hyprland \
        hyprlock \
        hypridle \
        hyprpaper \
        xdg-desktop-portal-hyprland \
        xdg-desktop-portal-gtk \
        xdg-user-dirs \
        qt6-qtwayland \
        qt5-qtwayland \
        qt6ct \
        pipewire \
        pipewire-alsa \
        pipewire-pulseaudio \
        pipewire-jack \
        wireplumber \
        grim \
        slurp \
        wl-clipboard \
        cliphist \
        swappy \
        brightnessctl \
        pamixer \
        playerctl \
        polkit-gnome \
        network-manager-applet \
        blueman \
        udiskie \
        libnotify \
        wayland-utils \
        || err "Hyprland/Wayland paketleri kurulamadı."

    # wlroots KALDIRILDI — Hyprland kendi wlroots fork'unu kullanır, sistem wlroots çakışır

    log "Hyprland + Wayland stack kuruldu."
}

# ─────────────────────────────────────────────────────────────
# 6. SDDM (Display Manager)
# ─────────────────────────────────────────────────────────────
install_sddm() {
    section "SDDM Display Manager"

    sudo dnf install -y sddm || err "SDDM kurulamadı."

    # GDM varsa devre dışı bırak
    if systemctl is-enabled gdm &>/dev/null 2>&1; then
        sudo systemctl disable gdm
        warn "GDM devre dışı bırakıldı."
    fi

    sudo systemctl enable sddm
    log "SDDM etkinleştirildi."
}

# ─────────────────────────────────────────────────────────────
# 7. NOCTALIA SHELL
# ─────────────────────────────────────────────────────────────
install_noctalia() {
    section "Noctalia Shell"

    sudo dnf install -y noctalia-shell \
        || warn "Noctalia Shell kurulamadı. Terra reposunu kontrol edin."
    mkdir -p ~/.config/noctalia

    log "Noctalia Shell kuruldu."
}

# ─────────────────────────────────────────────────────────────
# 8. GAMING CORE — Steam + Wine + Lutris + Protontricks
# ─────────────────────────────────────────────────────────────
install_gaming_core() {
    section "Gaming Core — Steam + Wine + Proton"

    # Steam (native — Flatpak değil, native daha iyi performans verir)
    sudo dnf install -y steam || warn "Steam kurulamadı."

    # Wine — wine-staging Fedora'da yok, sadece wine + winetricks kurulur
    sudo dnf install -y wine wine-core wine-common wine-desktop winetricks \
        || warn "Wine tam olarak kurulamadı, temel paketler denenecek."

    # Lutris
    sudo dnf install -y lutris || warn "Lutris kurulamadı."

    # Protontricks — önce dnf, yoksa pip
    sudo dnf install -y protontricks 2>/dev/null \
        || pip3 install protontricks --user 2>/dev/null \
        || warn "Protontricks kurulamadı, manuel kurulum gerekebilir."

    # Gaming kütüphaneleri — 32-bit dahil
    sudo dnf install -y \
        glibc.i686 \
        libstdc++.i686 \
        vulkan-loader.i686 \
        alsa-lib.i686 \
        SDL2 \
        SDL2.i686 \
        gamemode \
        gamemode.i686 \
        mangohud \
        mangohud.i686 \
        vkd3d \
        vkd3d.i686 \
        || warn "Bazı 32-bit gaming kütüphaneleri kurulamadı."

    # dxvk KALDIRILDI — Steam Proton kendi DXVK'sını getiriyor, çakışma yaratabilir

    # GameMode servisi — kullanıcı oturumu açık değilse hata verebilir, || true ile geçilir
    systemctl --user enable gamemoded 2>/dev/null || true

    log "Steam + Wine + Lutris + gaming kütüphaneleri kuruldu."
}

# ─────────────────────────────────────────────────────────────
# 9. GAMING APPS — Heroic, ProtonPlus, Bottles (Flatpak)
# ─────────────────────────────────────────────────────────────
install_gaming_apps() {
    section "Gaming Uygulamaları (Flatpak)"

    # Heroic Games Launcher (Epic / GOG / Amazon)
    flatpak install -y flathub com.heroicgameslauncher.hgl \
        || warn "Heroic Games Launcher kurulamadı."

    # ProtonPlus — Proton/Wine/GE sürüm yöneticisi
    flatpak install -y flathub com.vysp3r.ProtonPlus \
        || warn "ProtonPlus kurulamadı."

    # Flatseal — Flatpak izin yöneticisi (Heroic için gerekli)
    flatpak install -y flathub com.github.tchx84.Flatseal \
        || warn "Flatseal kurulamadı."

    # Bottles — Wine prefix yöneticisi
    flatpak install -y flathub com.usebottles.bottles \
        || warn "Bottles kurulamadı."

    # Discord
    flatpak install -y flathub com.discordapp.Discord \
        || warn "Discord kurulamadı."

    log "Gaming uygulamaları (Flatpak) kuruldu."
}

# ─────────────────────────────────────────────────────────────
# 10. GOOGLE CHROME
# ─────────────────────────────────────────────────────────────
install_chrome() {
    section "Google Chrome"
    sudo dnf install -y google-chrome-stable || warn "Google Chrome kurulamadı."
    log "Google Chrome kuruldu."
}

# ─────────────────────────────────────────────────────────────
# 11. TEMEL UYGULAMALAR & FONTLAR
# ─────────────────────────────────────────────────────────────
install_apps() {
    section "Temel Uygulamalar & Fontlar"

    sudo dnf install -y \
        kitty \
        thunar \
        thunar-volman \
        gvfs \
        ffmpegthumbnailer \
        tumbler \
        file-roller \
        wofi \
        neovim \
        nano \
        htop \
        btop \
        fastfetch \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        jetbrains-mono-fonts \
        fira-code-fonts \
        papirus-icon-theme \
        ffmpeg \
        p7zip \
        unrar \
        pavucontrol \
        || warn "Bazı temel uygulamalar kurulamadı."

    log "Temel uygulamalar kuruldu."
}

# ─────────────────────────────────────────────────────────────
# 12. HYPRLAND KONFİGÜRASYON
# ─────────────────────────────────────────────────────────────
setup_hyprland_config() {
    section "Hyprland Yapılandırması"
    mkdir -p ~/.config/hypr

    cat > ~/.config/hypr/hyprland.conf << 'HYPRCONF'
# ╔══════════════════════════════════════════════════╗
# ║  Hyprland Config — RX 9070 XT + Noctalia Shell  ║
# ╚══════════════════════════════════════════════════╝

monitor=,preferred,auto,1

# ── Otomatik Başlatma ────────────────────────────────
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = qs -c noctalia-shell
exec-once = hyprpaper
exec-once = hypridle
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = udiskie -t
exec-once = wl-paste --watch cliphist store

# ── Ortam Değişkenleri ───────────────────────────────
env = XCURSOR_SIZE,24
env = XCURSOR_THEME,Adwaita
env = QT_QPA_PLATFORM,wayland
env = QT_QPA_PLATFORMTHEME,qt6ct
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1
env = ELECTRON_OZONE_PLATFORM_HINT,wayland

# RX 9070 XT RDNA4 — Vulkan RADV (async compute tam aktif)
env = AMD_VULKAN_ICD,RADV
env = VK_ICD_FILENAMES,/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
env = RADV_PERFTEST,gpl,sam

# Steam Wayland
env = STEAM_FORCE_DESKTOPUI_SCALING,1

# ── Görünüm ──────────────────────────────────────────
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

# ── Girdi (Türkçe klavye) ────────────────────────────
input {
    kb_layout = tr
    follow_mouse = 1
    sensitivity = 0
}

# ── Tuş Bağlantıları ─────────────────────────────────
$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive
bind = $mainMod SHIFT, M, exit
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating
bind = $mainMod, D, exec, qs -c noctalia-shell ipc call launcher toggle
bind = $mainMod, F, fullscreen
bind = $mainMod SHIFT, S, exec, grim -g "$(slurp)" - | swappy -f -

# Noctalia Shell
bind = $mainMod, N, exec, qs -c noctalia-shell ipc call controlCenter toggle
bind = $mainMod SHIFT, L, exec, qs -c noctalia-shell ipc call lockScreen lock

# Gaming: Steam Big Picture
bind = $mainMod, G, exec, steam -gamepadui

# Pencere odağı
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Workspace geçişleri
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

# Ses kontrolleri
bindel = ,XF86AudioRaiseVolume, exec, pamixer -i 5
bindel = ,XF86AudioLowerVolume, exec, pamixer -d 5
bindl = ,XF86AudioMute, exec, pamixer -t
bindl = ,XF86AudioPlay, exec, playerctl play-pause
bindl = ,XF86AudioNext, exec, playerctl next
bindl = ,XF86AudioPrev, exec, playerctl previous

# Parlaklık
bindel = ,XF86MonBrightnessUp, exec, brightnessctl set +5%
bindel = ,XF86MonBrightnessDown, exec, brightnessctl set 5%-

# ── Oyun penceresi kuralları ─────────────────────────
windowrulev2 = fullscreen, class:^(steam_app_.*)$
windowrulev2 = immediate, class:^(steam_app_.*)$
windowrulev2 = float, class:^(steam)$, title:^(Steam - News.*)$
windowrulev2 = float, class:^(lutris)$
windowrulev2 = float, class:^(heroic)$
HYPRCONF

    log "hyprland.conf oluşturuldu."
}

# ─────────────────────────────────────────────────────────────
# 13. STEAM OPTİMİZASYON ŞABLONU
# ─────────────────────────────────────────────────────────────
setup_steam_optimizations() {
    section "Steam Gaming Optimizasyonları"

    mkdir -p ~/.config/steam
    mkdir -p ~/.local/share/Steam/config

    cat > ~/STEAM_LAUNCH_OPTIONS.txt << 'EOF'
# ════════════════════════════════════════════════════
#  Steam Oyun Başlatma Seçenekleri — RX 9070 XT
#  Steam > Oyun > Özellikler > Başlatma Seçenekleri
# ════════════════════════════════════════════════════

# ► Tam önerilen (GameMode + MangoHUD + RADV):
RADV_PERFTEST=gpl,sam AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

# ► Sadece GameMode (daha az overhead):
gamemoderun %command%

# ► Sadece MangoHUD (FPS overlay):
mangohud %command%

# ► Shader önbelleği koru:
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 %command%

# ► RX 9070 XT saf Vulkan performans:
RADV_PERFTEST=gpl,sam AMD_VULKAN_ICD=RADV %command%

# NOT: MangoHUD oyun içi kısayolu → Sol Shift + Sağ Shift + F12
EOF

    log "Steam optimizasyon şablonu ~/STEAM_LAUNCH_OPTIONS.txt olarak kaydedildi."
}

# ─────────────────────────────────────────────────────────────
# 14. DUVAR KAĞIDI
# ─────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────
# 15. ZSH + OH-MY-ZSH + XDG
# ─────────────────────────────────────────────────────────────
setup_shell() {
    section "Shell & XDG Ayarları"

    xdg-user-dirs-update

    sudo dnf install -y zsh || warn "ZSH kurulamadı."
    sudo chsh -s /bin/zsh "$USER"

    if [ ! -d ~/.oh-my-zsh ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
            || warn "Oh-My-ZSH kurulamadı, manuel kurulabilir."
    fi

    log "ZSH varsayılan shell yapıldı."
}

# ─────────────────────────────────────────────────────────────
# ANA AKIŞ
# ─────────────────────────────────────────────────────────────
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
    echo "║                                                              ║"
    echo "║  → sudo reboot ile sistemi yeniden başlatın                 ║"
    echo "║  → SDDM ekranında 'Hyprland' oturumunu seçin               ║"
    echo "║                                                              ║"
    echo "║  Kısayollar:                                                 ║"
    echo "║    Super+Enter    → Terminal (kitty)                         ║"
    echo "║    Super+D        → Uygulama başlatıcı (Noctalia)           ║"
    echo "║    Super+N        → Bildirim / Kontrol merkezi               ║"
    echo "║    Super+Shift+L  → Ekran kilidi                             ║"
    echo "║    Super+G        → Steam Big Picture Mode                   ║"
    echo "║                                                              ║"
    echo "║  İlk açılışta yapılacaklar:                                  ║"
    echo "║    1. ProtonPlus aç → Proton-GE son sürümünü indir          ║"
    echo "║    2. Steam → Ayarlar → Uyumluluk → Proton-GE seç          ║"
    echo "║    3. ~/STEAM_LAUNCH_OPTIONS.txt dosyasını incele           ║"
    echo "║    4. Heroic → Wine Manager → GE-Proton indir               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

main "$@"
