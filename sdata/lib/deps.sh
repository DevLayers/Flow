# Flow bootstrap — dependency registry.
#
# Sourced by setup-flow.sh. A single structured registry drives install and
# doctor, so package knowledge lives in one place instead of being repeated in
# checks all over the installer.
#
# Tiers:
#   core     — the minimal Flow terminal (required)
#   ux       — recommended ergonomics (optional)
#   devops   — DevOps profile, installed only on request (optional)
#   shell    — Quickshell desktop runtime (required for the shell)
#   fonts    — UI font families, verified not installed (optional)
#   terminal — font/terminal verification (never force-installed)
#
# A bin field of "fc:<family>" means the capability is a fontconfig family
# checked via `fc-list | grep -iF`, not an executable on PATH. A bin of
# "pkg:<name>" probes the package manager instead (library-only packages).
#
# API:
#   flow_dep <key> <tier> <package> <reason> [bin]
#   deps_entries                        -> all registry lines "key tier pkg reason bin"
#   deps_by_tier <tier>                 -> keys in that tier
#   deps_missing <tier...>              -> keys whose binary is absent
#   deps_packages <keys...>             -> package names for keys
#   deps_installed <key>                -> 0 when the binary exists
#   deps_version <key>                  -> prints the installed version (best effort)
#   deps_tier_label <tier>              -> human label
#
# Bins are preferred over package queries: presence of the executable is the
# capability we care about, and it correctly recognizes tools installed via
# cargo, mise shims, or the AUR without forcing package ownership.

declare -g -a FLOW_DEPS=()

flow_dep() {
    local key="$1" tier="$2" pkg="$3" reason="$4" bin="$5"
    # NOTE: the default must be applied in a separate statement — bash expands
    # every word of `local` BEFORE assigning, so ${5:-$key} inline sees an
    # unassigned $key and silently stores an empty bin.
    bin="${bin:-$key}"
    FLOW_DEPS+=("$key|$tier|$pkg|$reason|$bin")
}

deps_entries() {
    local e
    for e in ${FLOW_DEPS[@]+"${FLOW_DEPS[@]}"}; do
        printf '%s\n' "$e"
    done
}

deps_by_tier() {
    local tier="$1" e key t
    for e in ${FLOW_DEPS[@]+"${FLOW_DEPS[@]}"}; do
        key="${e%%|*}"
        rest="${e#*|}"
        t="${rest%%|*}"
        if [[ "$t" == "$tier" ]]; then
            printf '%s\n' "$key"
        fi
    done
}

deps_installed() {
    local key="$1" e bin
    for e in ${FLOW_DEPS[@]+"${FLOW_DEPS[@]}"}; do
        [[ "${e%%|*}" == "$key" ]] || continue
        bin="${e##*|}"
        # "fc:<family>" bins are font checks: the capability is a fontconfig
        # family, not an executable. fc-list alone proves nothing — grep it.
        if [[ "$bin" == fc:* ]]; then
            have fc-list && fc-list 2>/dev/null | grep -qiF "${bin#fc:}"
            return $?
        fi
        # "pkg:<name>" bins are library-only packages with no probe binary
        # (Qt modules): ask the package manager instead of PATH.
        if [[ "$bin" == pkg:* ]]; then
            if declare -F pkgmgr_installed >/dev/null; then
                pkgmgr_installed "${bin#pkg:}"
                return $?
            fi
            have "${bin#pkg:}"
            return $?
        fi
        have "$bin"
        return $?
    done
    return 1
}

deps_missing() {
    local tier k
    for tier in "$@"; do
        while IFS= read -r k; do
            [[ -z "$k" ]] && continue
            deps_installed "$k" || printf '%s\n' "$k"
        done < <(deps_by_tier "$tier")
    done
}

deps_packages() {
    local key e key_ tier pkg reason bin
    for key in "$@"; do
        for e in ${FLOW_DEPS[@]+"${FLOW_DEPS[@]}"}; do
            IFS='|' read -r key_ tier pkg reason bin <<<"$e"
            [[ "$key_" == "$key" ]] || continue
            printf '%s\n' "$pkg"
            break
        done
    done
}

deps_reason() {
    local key="$1" e key_ tier pkg reason bin
    for e in ${FLOW_DEPS[@]+"${FLOW_DEPS[@]}"}; do
        IFS='|' read -r key_ tier pkg reason bin <<<"$e"
        [[ "$key_" == "$key" ]] || continue
        printf '%s\n' "$reason"
        return 0
    done
    return 1
}

deps_bin() {
    local key="$1" e key_ tier pkg reason bin
    for e in ${FLOW_DEPS[@]+"${FLOW_DEPS[@]}"}; do
        IFS='|' read -r key_ tier pkg reason bin <<<"$e"
        [[ "$key_" == "$key" ]] || continue
        printf '%s\n' "$bin"
        return 0
    done
    return 1
}

# deps_is_font <key> — true when the entry's capability is a font family.
deps_is_font() {
    [[ "$(deps_bin "$1")" == fc:* ]]
}

# Best-effort first-line version of a tool. Kept in deps.sh because doctor and
# install both want it, and nothing else in the shell startup path should.
# Never fails: an unparseable tool just yields an empty version, which callers
# treat as "version unknown" (a failing command substitution would otherwise
# trip the installer's ERR trap).
tool_version() {
    local bin="$1" out v
    out="$("$bin" --version 2>/dev/null | head -n3)"
    [[ -z "$out" ]] && out="$("$bin" version 2>/dev/null | head -n3)"
    v="$(printf '%s' "$out" | head -n1)"
    # Drop trailing ")..." parentheticals and anything from the first " (" on.
    while [[ "$v" == *\) ]]; do
        v="${v%)}"
        v="${v%%(*}"
    done
    v="${v##* }"
    # Not version-shaped (e.g. eza's tagline)? Pull a semver-ish token.
    if [[ ! "$v" =~ ^[vV]?[0-9] ]]; then
        v="$(printf '%s' "$out" | grep -oE '[vV]?[0-9]+(\.[0-9]+){1,4}(-[0-9A-Za-z.]+)?' | head -n1)"
    fi
    printf '%s' "$v"
    return 0
}

deps_tier_label() {
    case "$1" in
        core) printf 'Core' ;;
        ux) printf 'UX' ;;
        devops) printf 'DevOps' ;;
        shell) printf 'Shell Runtime' ;;
        fonts) printf 'Fonts' ;;
        devops-gui) printf 'DevOps GUI' ;;
        terminal) printf 'Terminal' ;;
        *) printf '%s' "$1" ;;
    esac
}

# ── Registry ──────────────────────────────────────────────────────────────────
# Validated against the repo: every entry below is actually referenced by a
# zshrc.d module, the Starship config, or the Flow project engine. Nothing is
# installed just because it sounds useful.

flow_dep zsh core zsh "Zsh shell (Flow shell runtime)" zsh
flow_dep git core git "Git (project detection, Flow updates)" git
flow_dep starship core starship "Starship prompt" starship
flow_dep mise core mise "Runtime version manager (project profiles)" mise
flow_dep direnv core direnv "Per-project environment switching" direnv
flow_dep atuin core atuin "Shell history (local only, no sync)" atuin
# NOTE: the Flow Engine is NOT a pacman dependency — setup-flow.sh builds it
# from engine/ and installs to ~/.local/bin/iris (install_engine). Never point
# this tier at the upstream AUR "iris-autocomplete": that would install stock
# IRIS over our fork.
flow_dep fzf core fzf "Fuzzy finder" fzf
flow_dep fd core fd "Fast find (FZF default command)" fd
flow_dep ripgrep core rg "Fast grep (zshrc.d, FZF)" rg
flow_dep zoxide core zoxide "Smarter cd (zshrc.d)" zoxide

flow_dep bat ux bat "Syntax-highlighting cat (zshrc.d aliases)" bat
flow_dep eza ux eza "Modern ls (zshrc.d aliases)" eza
flow_dep lazygit ux lazygit "Terminal git UI (zshrc.d alias lg)" lazygit

flow_dep docker devops docker "Containers" docker
flow_dep kubectl devops kubectl "Kubernetes CLI" kubectl
flow_dep helm devops helm "Kubernetes package manager" helm
flow_dep terraform devops terraform "Infrastructure as code (Terraform)" terraform
flow_dep opentofu devops opentofu "OpenTofu (Terraform drop-in)" tofu
flow_dep ansible devops ansible "Configuration management" ansible
flow_dep gh devops github-cli "GitHub CLI" gh
flow_dep aws-cli devops aws-cli "AWS CLI" aws
flow_dep k9s devops k9s "Kubernetes TUI" k9s
flow_dep stern devops stern "Multi-pod log tailing" stern
flow_dep kubectx devops kubectx "Kube context switcher" kubectx
flow_dep kubens devops kubectx "Kube namespace switcher (part of kubectx)" kubens
flow_dep lazydocker devops lazydocker "Docker TUI" lazydocker
flow_dep delta devops git-delta "Diff pager" delta
flow_dep docker-compose devops docker-compose "Compose v2" docker-compose
flow_dep yq devops go-yq "YAML/TOML processor (mikefarah yq)" yq
flow_dep trivy devops trivy "Container/IaC vulnerability scanner" trivy
flow_dep ansible-lint devops ansible-lint "Ansible playbook linter" ansible-lint
flow_dep tflint devops tflint "Terraform linter" tflint
flow_dep terragrunt devops terragrunt "Terraform wrapper (DRY infra)" terragrunt
flow_dep sops devops sops "Secrets encryption for git" sops
flow_dep age devops age "Modern encryption (sops backend)" age
flow_dep dive devops dive "Docker image layer inspector" dive
flow_dep cosign devops cosign "Container signing/verification" cosign
flow_dep vault devops vault "HashiCorp Vault CLI" vault
flow_dep pre-commit devops pre-commit "Git hook framework (tf/ansible linting)" pre-commit
flow_dep tmux devops tmux "Terminal multiplexer (long-running ops)" tmux
flow_dep argocd devops argocd "GitOps CD CLI" argocd
flow_dep eksctl devops eksctl "EKS cluster CLI" eksctl
flow_dep kustomize devops kustomize "K8s templating" kustomize
flow_dep kind devops kind "Local K8s clusters in Docker (test before prod)" kind

# GUIs — AUR (-bin builds). CNCF Headlamp is the maintained standard;
# Freelens is the MIT continuation of the classic Lens UX.
flow_dep headlamp devops-gui headlamp-bin "Kubernetes desktop IDE (CNCF)" headlamp
flow_dep freelens devops-gui freelens-bin "Kubernetes desktop IDE (Lens fork)" freelens

# Fonts are verified, never force-installed: the terminal font preference is the
# user's own. `package` is the pacman extra package that satisfies it.

# ── Shell runtime (QuickShell + Flow Engine requirements) ──────────────────
# Two kinds of entries live here:
#   1. Qt/QML/theming runtime the desktop needs to render.
#   2. Every userspace CLI tool the config execs (Process/command/ scripts) —
#      audited 1:1 against nandoroid-shell data/dependencies.json and the QML.
# Deliberately NOT here (managed by the OS/compositor, or feature-detected):
#   pipewire, networkmanager, bluez, polkit agents, xdg portals, hyprland,
#   warp-cli, easyeffects-daemon, nwg-look/qt5ct/qt6ct (never exec'd),
#   mpvpaper/socat (livewallpaper feature not wired into Flow).
# Package names are Arch-style; pkgmgr passes them through as-is.
flow_dep quickshell-git   shell quickshell-git    "Desktop shell framework"      quickshell
flow_dep qt6-declarative  shell  qt6-declarative  "Qt6 QML library"              qml6
flow_dep qt6-svg          shell  qt6-svg          "Qt6 SVG support"              pkg:qt6-svg
flow_dep qt6-wayland      shell  qt6-wayland      "Qt6 Wayland support"          pkg:qt6-wayland
flow_dep qt6-5compat      shell  qt6-5compat      "Qt5Compat GraphicalEffects (85 QML imports)" pkg:qt6-5compat
flow_dep matugen-bin      shell  matugen-bin      "Material theme generator"     matugen
flow_dep python3          shell  python           "Theme generation backend"     python3
flow_dep jq               shell  jq               "JSON processing engine"       jq

# Tools exec'd by the shell (screenshots, media, dialogs, power, clipboard…)
flow_dep libnotify        shell  libnotify        "Notifications (notify-send)"  notify-send
flow_dep zenity           shell  zenity           "System file/dialog prompts"   zenity
flow_dep brightnessctl    shell  brightnessctl    "Backlight control (OSD)"      brightnessctl
flow_dep playerctl        shell  playerctl        "Media control (mpris)"        playerctl
flow_dep upower           shell  upower           "Battery info daemon client"   upower
flow_dep grim             shell  grim             "Screenshot capture"           grim
flow_dep slurp            shell  slurp            "Region selection"             slurp
flow_dep wf-recorder      shell  wf-recorder      "Screen recording"             wf-recorder
flow_dep imagemagick      shell  imagemagick      "Image processing (magick)"    magick
flow_dep ffmpeg           shell  ffmpeg           "Multimedia framework"         ffmpeg
flow_dep cava             shell  cava             "Audio visualizer"             cava
flow_dep songrec          shell  songrec          "Music recognition"            songrec
flow_dep hyprpicker       shell  hyprpicker       "Color picker"                 hyprpicker
flow_dep hyprlock         shell  hyprlock         "Session locker"               hyprlock
flow_dep hyprsunset       shell  hyprsunset       "Blue light filter"            hyprsunset
flow_dep wl-clipboard     shell  wl-clipboard     "Wayland clipboard (wl-copy)"  wl-copy
flow_dep cliphist         shell  cliphist         "Clipboard history"            cliphist
flow_dep translate-shell  shell  translate-shell  "CLI translation (trans)"      trans

# ── Fonts ────────────────────────────────────────────────────────────────────
# Verified via fontconfig families ("fc:<family>" bins), never force-installed:
# a missing family means the UI silently falls back, which doctor must surface.
# A pkg of "-" marks a font with no distro package: bootstrap skips it from the
# pacman/dnf transaction and tells the user how it is really installed
# (bootstrap_fonts clones Google Sans Flex from GitHub).
flow_dep google-sans-flex fonts -                                  "UI font (installed from GitHub)" "fc:Google Sans Flex"
flow_dep material-symbols fonts ttf-material-symbols-variable-git  "Material Symbols icons"          "fc:Material Symbols Rounded"
flow_dep noto-emoji       fonts noto-fonts-emoji                   "Emoji font"                      "fc:Noto Color Emoji"

flow_dep jetbrains-mono-nerd terminal ttf-jetbrains-mono-nerd "Nerd Font glyphs (Starship/terminal)" "fc:JetBrainsMono Nerd Font"