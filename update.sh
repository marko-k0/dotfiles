#!/bin/bash
# Refresh everything the chezmoi hooks installed.
#
# Why this exists: chezmoi only executes run_once_/run_onchange_ scripts when
# their *contents* change, so upstream releases (Go, Neovim, plugins) are never
# picked up by a plain `chezmoi apply`. Re-running the hooks directly is the
# supported way to move forward.
#
# Every hook self-checks and exits fast when already current, so this is safe
# to re-run at any time.
#
# Usage:
#   ./update.sh            # toolchains and plugins
#   ./update.sh --system   # also upgrade distro packages (apt/pacman)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$REPO_DIR/.chezmoiscripts"

log()  { echo "==> [update] $*"; }
warn() { echo "WARNING: [update] $*" >&2; }

usage() {
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

SYSTEM=false
for arg in "$@"; do
    case "$arg" in
        --system) SYSTEM=true ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $arg (try --help)" >&2
            exit 2
            ;;
    esac
done

# Track failures instead of aborting: one dead network call should not stop the
# rest of the update.
failed=()
run_step() {
    local name="$1"
    shift
    if "$@"; then
        return 0
    fi
    warn "${name} failed"
    failed+=("$name")
}

# ---------------------------------------------------------------------------
# Distro packages (opt-in: this is the one step that upgrades the whole system)
# ---------------------------------------------------------------------------
if $SYSTEM; then
    if command -v apt-get >/dev/null 2>&1; then
        log "Upgrading distro packages (apt)"
        run_step "apt upgrade" bash -c 'sudo apt-get update -qq && sudo apt-get -y upgrade'
    elif command -v pacman >/dev/null 2>&1; then
        log "Upgrading distro packages (pacman)"
        run_step "pacman -Syu" sudo pacman -Syu --noconfirm
    else
        warn "no supported package manager (apt-get/pacman)"
    fi
fi

# ---------------------------------------------------------------------------
# Toolchains installed by the chezmoi hooks (same scripts, re-run directly)
# ---------------------------------------------------------------------------
if [ -f "$SCRIPTS/run_onchange_50_go.sh" ]; then
    run_step "go" bash "$SCRIPTS/run_onchange_50_go.sh"
fi

if ! command -v nvim >/dev/null 2>&1 && [ -f "$SCRIPTS/run_once_before_10_neovim.sh" ]; then
    # Only when Neovim is absent: the hook is a bootstrap, and its NvChad step
    # re-clones the config tree. Updating an existing install is a no-op anyway
    # (it keeps any version >= 0.10), so calling it on every update adds risk
    # without benefit. NvChad itself is pulled below.
    run_step "neovim" bash "$SCRIPTS/run_once_before_10_neovim.sh"
fi

# NvChad is a git clone owned by chezmoi's custom layer: pull it forward.
if [ -d "$HOME/.config/nvim/.git" ]; then
    log "Updating NvChad (git pull)"
    run_step "nvchad" git -C "$HOME/.config/nvim" pull --ff-only
fi

# ---------------------------------------------------------------------------
# Plugin managers (their own update paths)
# ---------------------------------------------------------------------------
if [ -x "$HOME/.tmux/plugins/tpm/bin/update_plugins" ]; then
    log "Updating tmux plugins"
    run_step "tpm" "$HOME/.tmux/plugins/tpm/bin/update_plugins" all
fi

if command -v fish >/dev/null 2>&1 \
    && [ -f "$HOME/.config/fish/fish_plugins" ] \
    && fish -c 'functions -q fisher' 2>/dev/null; then
    log "Updating fish plugins (fisher)"
    run_step "fisher" fish -c 'fisher update' >/dev/null
fi

if command -v nvim >/dev/null 2>&1 && [ -d "$HOME/.config/nvim/lua/core" ]; then
    log "Updating Neovim plugins (Lazy)"
    # Headless Lazy update; quiet (very noisy) and non-fatal when offline.
    run_step "lazy" nvim --headless "+Lazy! update" +qa >/dev/null 2>&1
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "${#failed[@]}" -eq 0 ]; then
    log "done: everything up to date"
    exit 0
fi

warn "finished with ${#failed[@]} failure(s): ${failed[*]}"
exit 1
