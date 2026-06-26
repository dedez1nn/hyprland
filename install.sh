#!/usr/bin/env bash
# install.sh — Hyprland Liquid Glass dotfiles installer

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$HOME/.config"
WALLPAPERS_DIR="$HOME/Imagens/wallpapers"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { printf "${GREEN}[+]${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}[!]${NC} %s\n" "$1"; }
confirm() {
    read -rp "    $1 [s/N] " ans
    [[ "${ans,,}" == "s" ]]
}

# ── backup ──────────────────────────────────────────────────────────────────
backup_dir="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"

backup_if_exists() {
    local src="$1"
    if [ -e "$src" ] && [ ! -L "$src" ]; then
        mkdir -p "$backup_dir"
        cp -r "$src" "$backup_dir/"
        warn "Backup: $src → $backup_dir/"
    fi
}

# ── copy helper ──────────────────────────────────────────────────────────────
install_config() {
    local name="$1"
    local src="$DOTFILES/.config/$name"
    local dst="$CONFIG/$name"

    [ -d "$src" ] || { warn "Skipping $name (not found in dotfiles)"; return; }
    backup_if_exists "$dst"
    mkdir -p "$dst"
    rsync -a --delete "$src/" "$dst/"
    info "Installed $name"
}

# ── post-copy path fixup ──────────────────────────────────────────────────────
fix_placeholder() {
    local file="$1"
    [ -f "$file" ] || return
    sed -i "s|HOME_PLACEHOLDER|$HOME|g" "$file"
}

# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "  Hyprland Liquid Glass — instalador de dotfiles"
echo "  Origem : $DOTFILES"
echo "  Destino: $CONFIG"
echo ""

if ! confirm "Continuar? Configs existentes serão salvas em backup."; then
    echo "Cancelado."
    exit 0
fi

# ── wallpapers ───────────────────────────────────────────────────────────────
if [ -d "$DOTFILES/wallpapers" ]; then
    info "Instalando wallpapers em $WALLPAPERS_DIR"
    mkdir -p "$WALLPAPERS_DIR"
    rsync -a "$DOTFILES/wallpapers/" "$WALLPAPERS_DIR/"
else
    warn "Pasta wallpapers/ não encontrada nos dotfiles, pulando."
fi

# ── configs ──────────────────────────────────────────────────────────────────
for dir in waybar hypr kitty ghostty rofi swaync wlogout nwg-bar btop fastfetch wallust cava fish; do
    install_config "$dir"
done

# ── zshrc ────────────────────────────────────────────────────────────────────
if [ -f "$DOTFILES/.zshrc" ]; then
    backup_if_exists "$HOME/.zshrc"
    cp "$DOTFILES/.zshrc" "$HOME/.zshrc"
    info "Installed .zshrc"
fi

# ── fix hardcoded HOME paths ──────────────────────────────────────────────────
info "Corrigindo paths com HOME_PLACEHOLDER → $HOME"
fix_placeholder "$CONFIG/hypr/hyprpaper.conf"
fix_placeholder "$CONFIG/hypr/hyprlock.conf"
fix_placeholder "$CONFIG/waybar/style/[Extra] Liquid Glass.css"

# ── waybar active layout symlinks ────────────────────────────────────────────
WAYBAR="$CONFIG/waybar"
info "Configurando symlinks da Waybar"

# active config layout → configs/[TOP] Andre Liquid Glass
ln -sfn "$WAYBAR/configs/[TOP] Andre Liquid Glass" "$WAYBAR/config"

# active style → style/[Extra] Liquid Glass.css
ln -sfn "$WAYBAR/style/[Extra] Liquid Glass.css" "$WAYBAR/style.css"

info "Symlinks criados: waybar/config e waybar/style.css"

# ── script permissions ────────────────────────────────────────────────────────
info "Tornando scripts executáveis"
find "$CONFIG/waybar" -name "*.sh" -exec chmod +x {} \;
find "$CONFIG/hypr/UserScripts" -name "*.sh" -exec chmod +x {} \;
find "$CONFIG/hypr/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# ── hyprpaper wallpaper path (usa fundo3.jpg por padrão) ────────────────────
# Se o wallpaper padrão não existir, substitui pelo primeiro disponível
DEFAULT_WALL="$WALLPAPERS_DIR/fundo3.jpg"
if [ ! -f "$DEFAULT_WALL" ]; then
    FIRST_WALL=$(find "$WALLPAPERS_DIR" -maxdepth 1 \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) | sort | head -n 1)
    if [ -n "$FIRST_WALL" ]; then
        warn "fundo3.jpg não encontrado, usando: $FIRST_WALL"
        sed -i "s|$WALLPAPERS_DIR/fundo3.jpg|$FIRST_WALL|g" "$CONFIG/hypr/hyprpaper.conf"
        sed -i "s|$WALLPAPERS_DIR/fundo3.jpg|$FIRST_WALL|g" "$CONFIG/hypr/hyprlock.conf"
    fi
fi

# ── done ─────────────────────────────────────────────────────────────────────
echo ""
info "Instalação concluída!"
echo ""
echo "  Próximos passos:"
echo "  1. Instale as dependências listadas no README.md"
echo "  2. Configure o widget de clima em:"
echo "     ~/.config/hypr/UserScripts/Weather.py"
echo "     (ajuste MANUAL_PLACE, MANUAL_LAT, MANUAL_LON)"
echo "  3. Faça logout e entre novamente no Hyprland"
if [ -d "$backup_dir" ]; then
    echo ""
    warn "Configs anteriores salvas em: $backup_dir"
fi
echo ""
