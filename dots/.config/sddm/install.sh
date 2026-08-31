#!/usr/bin/env bash

# Non-interactive mode: pass -y/--yes to auto-confirm every prompt (used when
# install.sh drives this during post-install). Still requires sudo for the
# system-level config writes.
AUTO=""
case "$1" in
    -y|--yes) AUTO=1 ;;
esac

# Installs/configures SDDM with the vendored Flow greeter theme (apps/sddm/theme,
# staged to ~/.local/share/dotfiles/apps/sddm/theme) — the hyprlock design as a
# login screen. Wires it to auto-sync the desktop wallpaper + matugen colors and
# resolves any old conflicting Current= themes by writing ONE authoritative
# /etc/sddm.conf.d/theme.conf.

# --- 1. PRE-FLIGHT CHECKS ---
if [ -z "$AUTO" ] && ! command -v gum &> /dev/null; then
    echo "Error: 'gum' is not installed. Please install gum first."
    exit 1
fi

DISTRO="Arch Linux"
CHECK_PKG_CMD="pacman -Qi sddm"

# qt6-5compat provides Qt5Compat.GraphicalEffects (FastBlur/DropShadow) used by
# the Flow greeter; inter-font is the greeter's (and the whole shell's) UI font.
INSTALL_CMD_OFFICIAL="sudo pacman -S --needed --noconfirm sddm qt6-svg qt6-5compat qt6-virtualkeyboard qt6-multimedia-ffmpeg inter-font"

# Gum prompt colors — read from the shell's generated matugen palette when available.
GENERATED_COLORS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
primarycolor=$(jq -r '.primary // empty' "$GENERATED_COLORS_FILE" 2>/dev/null)
onsurfacecolor=$(jq -r '.on_surface // empty' "$GENERATED_COLORS_FILE" 2>/dev/null)
onprimarycolor=$(jq -r '.on_primary // empty' "$GENERATED_COLORS_FILE" 2>/dev/null)

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/flow"

THEME_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme"
THEME_DIR="/usr/share/sddm/themes/flow"
# World-readable, user-owned dir so the 'sddm' greeter can read the config
# and background (it cannot traverse ~/.cache). Uses /var/tmp: it's
# world-writable + world-traversable (so the sddm user can read it) and needs
# NO root to create — only the copy into /usr/share needs root.
SDDM_DOTFILES_DIR="/var/tmp/sddm-dotfiles"
GENERATED_CONF="$SDDM_DOTFILES_DIR/theme.conf"
SDDM_CONF_D="/etc/sddm.conf.d"

# Run a command as root via interactive sudo (prompts for the password in a
# terminal). Credentials are cached after the first prompt, so the few root
# operations in this script only ask once. This must be run in an interactive
# session — never piped/silenced.
rootdo() { sudo "$@"; }

check_sddm_installed() { $CHECK_PKG_CMD &> /dev/null; }
check_sddm_active()    { systemctl is-active --quiet display-manager; }

disable_other_dms() {
    for dm in gdm lightdm lxdm xdm mdm slim wdm; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null; then
            echo ":: Disabling conflicting DM: $dm..." && rootdo systemctl disable "$dm"
        fi
    done
}

install_sddm() {
    sudo -v || exit 1
    echo ":: Installing SDDM + qt deps on $DISTRO..." && bash -c "$INSTALL_CMD_OFFICIAL"
}

activate_sddm() {
    sudo -v || exit 1
    disable_other_dms
    echo ":: Enabling SDDM Service..." && if sudo systemctl enable sddm; then
        echo ":: SDDM Service Enabled. Reboot to apply changes."
    else
        echo "ERROR: Failed to enable SDDM systemd service."
        exit 1
    fi
}

# Write ONE authoritative SDDM config and remove every conflicting Current= file.
write_sddm_config() {
    sudo -v >/dev/null 2>&1 || true   # prompt for password once, cache it
    echo ":: Writing single SDDM config (theme=flow) and removing conflicts..."
    rootdo mkdir -p "$SDDM_CONF_D"
    for f in "$SDDM_CONF_D"/*.conf; do
        [ -e "$f" ] || continue
        if rootdo grep -qE '^[[:space:]]*Current[[:space:]]*=' "$f"; then
            echo "   removing conflicting: $f"
            rootdo rm -f "$f"
        fi
    done
    # A stray top-level /etc/sddm.conf would override .conf.d — drop it.
    if [ -f /etc/sddm.conf ]; then
        rootdo cp -f /etc/sddm.conf /etc/sddm.conf.bak
        rootdo rm -f /etc/sddm.conf
    fi
    # Write to a temp file, then move into place as root.
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<EOF
[Theme]
Current=flow

[General]
DisplayServer=wayland
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
Numlock=on
EOF
    rootdo cp -f "$tmp" "$SDDM_CONF_D/theme.conf"
    rm -f "$tmp"
}

# Copy the vendored Flow theme into /usr/share/sddm/themes and point its
# theme.conf at the matugen-generated, world-readable config.
install_flow_theme() {
    sudo -v >/dev/null 2>&1 || true   # prompt for password once, cache it
    if [ ! -d "$THEME_SRC" ]; then
        echo "ERROR: Vendored Flow SDDM theme not found at $THEME_SRC"
        return 1
    fi
    echo ":: Installing Flow SDDM theme to $THEME_DIR..."
    rootdo mkdir -p "$THEME_DIR"
    rootdo cp -rf "$THEME_SRC"/. "$THEME_DIR"/

    # Drop the leftover theme from the previous dotfiles project if present.
    if [ -d /usr/share/sddm/themes/where_is_my_sddm_theme ]; then
        echo ":: Removing stale theme: where_is_my_sddm_theme..."
        rootdo rm -rf /usr/share/sddm/themes/where_is_my_sddm_theme
    fi

    echo ":: Deploying matugen-driven theme.conf..."
    # Create a world-readable, user-owned dir for the generated config + background
    # so the 'sddm' greeter (which can't read ~/.cache) can load them.
    rootdo mkdir -p "$SDDM_DOTFILES_DIR"
    rootdo chown "$(id -u):$(id -g)" "$SDDM_DOTFILES_DIR"
    chmod 755 "$SDDM_DOTFILES_DIR"
    # Seed a sane default config if matugen hasn't generated one yet, so the
    # greeter never falls back to a broken/blank screen.
    if [ ! -f "$GENERATED_CONF" ] || ! grep -q '^blurRadius=' "$GENERATED_CONF" 2>/dev/null; then
        cat > "$GENERATED_CONF" <<'CFG'
[General]
background=/var/tmp/sddm-dotfiles/current_wallpaper
backgroundFill=#131314
blurRadius=48
font=Inter
accentColor=#c0c7d5
errorColor=#ffb4ab
CFG
    fi
    # Seed the wallpaper mirror so SDDM is never blank: prefer the shell's live
    # wallpaper, then the bundled default. The theme blurs it itself.
    CUR_WALL="$(jq -r '.background.wallpaperPath // empty' "$XDG_CONFIG_HOME/flow/config.json" 2>/dev/null)"
    [ -n "$CUR_WALL" ] || CUR_WALL="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/wallpaper/path.txt" 2>/dev/null)"
    if [ -n "$CUR_WALL" ] && [ -f "$CUR_WALL" ]; then
        cp -f "$CUR_WALL" "$SDDM_DOTFILES_DIR/current_wallpaper" 2>/dev/null || true
    elif [ -f "$CONFIG_DIR/assets/images/default_wallpaper.png" ]; then
        cp -f "$CONFIG_DIR/assets/images/default_wallpaper.png" "$SDDM_DOTFILES_DIR/current_wallpaper" 2>/dev/null || true
    fi
    chmod 644 "$GENERATED_CONF" "$SDDM_DOTFILES_DIR/current_wallpaper" 2>/dev/null || true
    # Point the theme's theme.conf at our generated, world-readable file.
    rootdo ln -sf "$GENERATED_CONF" "$THEME_DIR/theme.conf" || \
        echo ":: WARN: could not create the theme symlink (no root). Run: sudo ln -sf '$GENERATED_CONF' '$THEME_DIR/theme.conf'"
}

# --- 4. MAIN LOGIC ---
if [ -z "$AUTO" ]; then clear; figlet -f smslant "Flow SDDM"; fi

if ! check_sddm_installed; then
    echo ":: Status: SDDM not installed."
    if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Install SDDM + Flow greeter theme?"; then
        install_sddm
        if check_sddm_installed; then
            write_sddm_config
            install_flow_theme
            if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Activate SDDM now?"; then
                activate_sddm
            fi
        else
            echo "ERROR: Installation failed."
            exit 1
        fi
    else
        echo ":: Installation cancelled."
        exit 0
    fi
elif ! check_sddm_active; then
    echo ":: SDDM is installed but NOT active."
    install_sddm   # --needed: only fills in missing qt deps / inter-font
    write_sddm_config
    install_flow_theme
    if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Activate SDDM now?"; then
        activate_sddm
    fi
else
    echo ":: SDDM is installed and active."
    if [ -n "$AUTO" ]; then
        ACTION="Re-apply SDDM config"
    else
        ACTION=$(gum choose --selected.background=$primarycolor --selected.foreground=$onprimarycolor "Re-apply SDDM config" "Deactivate SDDM" "Exit")
    fi
    case $ACTION in
        "Re-apply SDDM config")
            install_sddm   # --needed: only fills in missing qt deps / inter-font
            write_sddm_config
            install_flow_theme
            echo ":: Re-applied. Reboot to see changes." ;;
        "Deactivate SDDM")
            if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Are you sure you want to deactivate SDDM?"; then
                sudo systemctl disable sddm
                echo ":: SDDM deactivated."
            fi ;;
        "Exit")
            echo "Exiting."; exit 0 ;;
    esac
fi

echo
if [ -z "$AUTO" ]; then echo ":: Done! Press [ENTER] to close."; read; fi
