# Flow bootstrap — package-manager abstraction.
#
# Sourced by setup-flow.sh (which supplies `have`, `run_logged`, `ui_*` and the
# OPT_* option variables). Arch/pacman is the primary supported platform; the
# interface below is kept generic so other managers can be added later without
# duplicating install logic in the callers.
#
# Interface:
#   detect_package_manager           -> prints pacman|apt|dnf|apk|brew|zypper|none
#   pkgmgr_sudo_ok                   -> 0 if sudo works without a password prompt (best effort)
#   pkgmgr_installed <pkg>           -> 0 if the package is installed
#   pkgmgr_plan <pkgs...>            -> prints the one transaction that would install them
#   pkgmgr_install <pkgs...>         -> runs one install transaction, returns its exit code
#
# Detection is by command presence, not distro-id: a machine that has both
# pacman and apt (chroot, container) uses whatever actually runs.

detect_package_manager() {
    if have pacman; then
        printf '%s' pacman
    elif have apt-get; then
        printf '%s' apt
    elif have dnf; then
        printf '%s' dnf
    elif have apk; then
        printf '%s' apk
    elif have brew; then
        printf '%s' brew
    elif have zypper; then
        printf '%s' zypper
    else
        printf '%s' none
    fi
}

# True if sudo exists and either already authenticates or can at least be run.
# A password prompt is fine for interactive installs; --yes installs still need
# one unless sudo -n succeeds.
pkgmgr_sudo_ok() {
    have sudo || return 1
    if [[ "${OPT_ASSUME_YES:-false}" == true ]]; then
        sudo -n true 2>/dev/null
    else
        return 0
    fi
}

pkgmgr_installed() {
    local pkg="$1" mgr
    mgr="$(detect_package_manager)"
    case "$mgr" in
        pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
        apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
        dnf) rpm -q "$pkg" >/dev/null 2>&1 ;;
        apk) apk info -e "$pkg" >/dev/null 2>&1 ;;
        brew) brew list --formula "$pkg" >/dev/null 2>&1 ;;
        zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# pkgmgr_plan <pkgs...> — prints the single transaction the install would run.
pkgmgr_plan() {
    local mgr
    mgr="$(detect_package_manager)"
    case "$mgr" in
        pacman) printf 'sudo pacman -S --needed --noconfirm %s' "$*" ;;
        apt) printf 'sudo apt-get install -y %s' "$*" ;;
        dnf) printf 'sudo dnf install -y %s' "$*" ;;
        apk) printf 'sudo apk add %s' "$*" ;;
        brew) printf 'brew install %s' "$*" ;;
        zypper) printf 'sudo zypper install -y %s' "$*" ;;
        none) printf '(no supported package manager found)' ;;
    esac
}

# pkgmgr_install <pkgs...> — installs everything in one transaction.
# Stream package-manager output LIVE to the terminal while still logging.
# Silent multi-minute installs read as "hung" — users must see progress.
pkg_run_stream() {
    local rc=0
    if [[ -n "${LOG_FILE:-}" && -w "$(dirname "$LOG_FILE")" ]]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
        rc=${PIPESTATUS[0]}
    else
        "$@"; rc=$?
    fi
    return $rc
}

pkgmgr_install() {
    (($# == 0)) && return 0
    local mgr
    mgr="$(detect_package_manager)"
    ui_info "$(pkgmgr_plan "$@")"
    case "$mgr" in
        pacman)
            local -a _repo=() _aur=() _p
            for _p in "$@"; do
                if pacman -Si "$_p" >/dev/null 2>&1; then _repo+=("$_p"); else _aur+=("$_p"); fi
            done
            if ((${#_repo[@]})); then
                run_logged sudo pacman -S --needed --noconfirm "${_repo[@]}"
            fi
            if ((${#_aur[@]})); then
                local _h=""
                for _h in yay paru; do command -v "$_h" >/dev/null 2>&1 && break; done
                _h="${_h:-yay}"
                ui_info "AUR ($_h): ${_aur[*]}"
                run_logged "$_h" -S --needed --noconfirm "${_aur[@]}"
            fi
            ;;
        apt) pkg_run_stream sudo apt-get install -y "$@" ;;
        dnf) pkg_run_stream sudo dnf install -y "$@" ;;
        apk) pkg_run_stream sudo apk add "$@" ;;
        brew) pkg_run_stream brew install "$@" ;;
        zypper) pkg_run_stream sudo zypper install -y "$@" ;;
        none)
            ui_fail "No supported package manager" "install these yourself: $*"
            return 1
            ;;
    esac
}