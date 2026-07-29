#!/usr/bin/env bash
# Install the end4-pC Discord Voice companion plugin for Vesktop / Equibop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="iiDiscordVoice"

notify() {
    local title="$1"
    local msg="$2"
    local urgency="${3:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$msg"
    fi
}

info() {
    printf '\033[1;34m:: %s\033[0m\n' "$*"
}

error() {
    local msg="$*"
    printf '\033[1;31m:: %s\033[0m\n' "$msg" >&2
    notify "Discord Voice Companion Error" "$msg" "critical"
    exit 1
}

# Environment setup: load NVM / Node / pnpm / Bun paths
if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh" || true
    fi
    latest_node="$(ls "$NVM_DIR/versions/node" 2>/dev/null | tail -1 || true)"
    if [ -n "$latest_node" ]; then
        export PATH="$NVM_DIR/versions/node/$latest_node/bin:$PATH"
    fi
fi

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.local/share/pnpm:$PATH"

# Validate required tools
missing_tools=()
for cmd in git node pnpm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_tools+=("$cmd")
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    error "Missing required dependencies: ${missing_tools[*]}. Please install them to proceed."
fi

# Detect client (Vesktop vs Equibop)
if [ -d "$HOME/.config/vesktop" ]; then
    CLIENT_NAME="Vesktop"
    REPO_URL="https://github.com/Vendicated/Vencord.git"
    BUILD_DIR="${HOME}/.local/share/quickshell-ii/Vencord"
    STATE_FILE="${HOME}/.config/vesktop/settings.json"
    VENCORD_SETTINGS="${HOME}/.config/vesktop/settings/settings.json"
    CONFIG_KEY="vencordLocation"
elif [ -d "$HOME/.config/equibop" ]; then
    CLIENT_NAME="Equibop"
    REPO_URL="https://github.com/Equicord/Equicord.git"
    BUILD_DIR="${HOME}/.local/share/quickshell-ii/Equicord"
    STATE_FILE="${HOME}/.config/equibop/state.json"
    VENCORD_SETTINGS="${HOME}/.config/equibop/settings/settings.json"
    CONFIG_KEY="equicordDir"
else
    CLIENT_NAME="Vesktop"
    REPO_URL="https://github.com/Vendicated/Vencord.git"
    BUILD_DIR="${HOME}/.local/share/quickshell-ii/Vencord"
    STATE_FILE="${HOME}/.config/vesktop/settings.json"
    VENCORD_SETTINGS="${HOME}/.config/vesktop/settings/settings.json"
    CONFIG_KEY="vencordLocation"
fi

notify "Discord Voice Overlay" "Installing $CLIENT_NAME Companion plugin..." "normal"
info "Installing companion for $CLIENT_NAME in $BUILD_DIR"

if [ -d "$BUILD_DIR" ]; then
    info "Updating existing checkout at $BUILD_DIR"
    git -C "$BUILD_DIR" pull --ff-only || true
else
    info "Cloning $CLIENT_NAME source to $BUILD_DIR"
    git clone "$REPO_URL" "$BUILD_DIR"
fi

PLUGIN_DIR="$BUILD_DIR/src/userplugins/$PLUGIN_NAME"
info "Installing plugin source files to $PLUGIN_DIR"
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
cp "$SCRIPT_DIR/index.ts" "$SCRIPT_DIR/native.ts" "$PLUGIN_DIR/"

info "Building companion plugin (this may take a few moments)..."
cd "$BUILD_DIR"
pnpm install --frozen-lockfile 2>/dev/null || pnpm install
pnpm build

DIST_DIR="$BUILD_DIR/dist"

if [ -f "$DIST_DIR/package.json" ]; then
    info "Build succeeded at $DIST_DIR"
else
    cp "$BUILD_DIR/package.json" "$DIST_DIR/" 2>/dev/null || true
fi

# Update settings file
WAS_RUNNING=0
if pgrep -f "vesktop" >/dev/null 2>&1; then
    WAS_RUNNING=1
    info "Closing $CLIENT_NAME to update settings cleanly..."
    pkill -f "vesktop" 2>/dev/null || true
    sleep 1
fi

if [ -f "$STATE_FILE" ]; then
    if command -v python3 &>/dev/null; then
        python3 -c "
import json
try:
    with open('$STATE_FILE') as f: data = json.load(f)
except Exception:
    data = {}
data['$CONFIG_KEY'] = '$DIST_DIR'
with open('$STATE_FILE', 'w') as f: json.dump(data, f, indent=4)
"
        info "Updated $CONFIG_KEY in $STATE_FILE"
    fi
else
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "{\"$CONFIG_KEY\": \"$DIST_DIR\"}" > "$STATE_FILE"
fi

# Enable plugin in Vencord settings
if [ -f "$VENCORD_SETTINGS" ]; then
    if command -v python3 &>/dev/null; then
        python3 -c "
import json
try:
    with open('$VENCORD_SETTINGS') as f: data = json.load(f)
except Exception:
    data = {}
if 'plugins' not in data: data['plugins'] = {}
data['plugins']['$PLUGIN_NAME'] = {'enabled': True}
with open('$VENCORD_SETTINGS', 'w') as f: json.dump(data, f, indent=4)
"
        info "Enabled $PLUGIN_NAME in Vencord settings"
    fi
fi

if [ $WAS_RUNNING -eq 1 ]; then
    info "Relaunching $CLIENT_NAME..."
    if command -v vesktop >/dev/null 2>&1; then
        nohup vesktop >/dev/null 2>&1 &
    elif [ -x "/opt/Vesktop/vesktop" ]; then
        nohup /opt/Vesktop/vesktop >/dev/null 2>&1 &
    fi
fi

notify "Discord Voice Overlay" "Companion plugin installed and $CLIENT_NAME restarted!" "normal"
info "Done! $CLIENT_NAME restarted with companion plugin."
