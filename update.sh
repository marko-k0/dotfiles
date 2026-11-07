#!/bin/bash
# Refresh the tooling that chezmoi hooks install, plus the plugin managers.
#
# Version policy: dev tools (go, neovim, kubectl, ...) are pinned in
# .chezmoidata/software.yaml. Bump the pin and run `chezmoi apply` to change a
# version; this script does not float them. It refreshes mise itself, applies
# any "latest" pins, regenerates the lockfile, and updates the plugin managers.
#
# Usage:
#   ./update.sh            # mise, plugins, lockfile
#   ./update.sh --system   # also upgrade distro packages (apt/pacman)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$REPO_DIR/.chezmoiscripts"

# mise shims so mise-managed tools (nvim, fzf, ...) resolve in this
# non-interactive shell.
if [ -d "$HOME/.local/share/mise/shims" ]; then
    PATH="$HOME/.local/share/mise/shims:$PATH"
    export PATH
fi

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

# Hooks are templates: chezmoi renders them (applying .chezmoidata/software.yaml)
# before running. Render the same way here so update.sh executes exactly what
# `chezmoi apply` would.
# shellcheck disable=SC2317  # called indirectly through run_step "$@"
render_and_run() {
    local tmpl="$1" tmp rc
    tmp="$(mktemp)"
    if ! chezmoi execute-template --source "$REPO_DIR" < "$tmpl" > "$tmp"; then
        warn "cannot render ${tmpl##*/}"
        rm -f "$tmp"
        return 1
    fi
    bash "$tmp"
    rc=$?
    rm -f "$tmp"
    return "$rc"
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
# mise-managed tools (versions from .chezmoidata/software.yaml)
# ---------------------------------------------------------------------------
MISE_BIN="$(command -v mise 2>/dev/null || true)"
[ -n "$MISE_BIN" ] || MISE_BIN="$HOME/.local/bin/mise"
if [ -x "$MISE_BIN" ]; then
    log "Updating mise itself"
    run_step "mise self-update" "$MISE_BIN" self-update -y --no-plugins
    # Pins govern upgrades; this only moves tools declared as "latest".
    log "Upgrading mise tools"
    run_step "mise upgrade" "$MISE_BIN" upgrade --yes
    log "Refreshing lockfile"
    run_step "mise lock" "$MISE_BIN" lock --global
    # Re-run the apply hook so system tool symlinks/shim dirs follow the pins.
    run_step "mise apply" render_and_run "$SCRIPTS/run_after_05_mise.sh.tmpl"
else
    warn "mise not found; skipping toolchain updates"
fi

# Neovim config is fully chezmoi-managed (LazyVim), so there is no upstream tree
# to pull: lazy.nvim updates LazyVim and every plugin.

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

if command -v nvim >/dev/null 2>&1 && [ -f "$HOME/.config/nvim/lua/config/lazy.lua" ]; then
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
