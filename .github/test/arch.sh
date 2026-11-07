#!/bin/bash
# Full end-to-end test of this repo on a bare Arch Linux container.
# Used by CI (.github/workflows/ci.yml) and runnable locally:
#   docker run --rm --network host -v "$PWD":/repo -w /repo \
#     archlinux:base-devel bash /repo/.github/test/arch.sh
# Runs as root: provisions a test user with passwordless sudo, runs
# init.sh as that user, then asserts the installed state.
set -euo pipefail

# Containers ship their own /etc/gai.conf. Mirror the host workaround: on
# networks where IPv6 to dl.google.com and sigstore TUF fails, downloads 404.
# No-op on IPv4-only runners (GitHub Actions).
grep -qE '^precedence[[:space:]]+::ffff:0:0/96' /etc/gai.conf 2>/dev/null \
    || echo 'precedence ::ffff:0:0/96 100' >> /etc/gai.conf

pacman -Syu --noconfirm >/dev/null
pacman -S --noconfirm --needed sudo git curl >/dev/null
useradd -m -s /bin/bash tester
echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DATA="$REPO/.chezmoidata/software.yaml"

# No `| head -1` (or `grep -q` downstream): with pipefail, a consumer exiting
# early sends SIGPIPE to the producer and the pipeline returns 141.
tool_pin() {
    sed -n '/^  tools:/,/^[a-z]/p' "$DATA" \
        | grep -E "^    \"?$1\"?:" \
        | sed 's/.*"\([^"]*\)"[[:space:]]*$/\1/'
}

echo "=== Running init.sh as tester ==="
su tester -c "HOME=/home/tester bash $REPO/init.sh" 2>&1 | tee /tmp/init.log

echo "=== All setup scripts must have run ==="
# claude/happier skip in CI (their installers 403 datacenter IPs)
for stage in packages mise nvim tmux fish nvim-plugins shell; do
    grep -q "==> \[$stage\]" /tmp/init.log || {
        echo "ERROR: [${stage}] script never ran" >&2; exit 1;
    }
done
grep -q "\[claude\] CI environment detected" /tmp/init.log || {
    echo "ERROR: claude script did not hit its CI skip" >&2; exit 1;
}

echo "=== Assertions ==="
test -x /usr/bin/fish
test -x /usr/bin/direnv
# Hybrid mode: go is linked into /usr/local/bin (mise owns the version)
test -x /usr/local/bin/go
/usr/local/bin/go version
# Arch no longer installs neovim/fzf from pacman: mise owns them
if pacman -Q neovim >/dev/null 2>&1; then
    echo "ERROR: neovim should be mise-managed, not pacman-installed" >&2; exit 1
fi
if pacman -Q go >/dev/null 2>&1; then
    echo "ERROR: go should be mise-managed, not pacman-installed" >&2; exit 1
fi
test -f /home/tester/.config/fish/config.fish
fish -n /home/tester/.config/fish/config.fish
grep -q "mise activate fish" /home/tester/.config/fish/config.fish
test -f /home/tester/.config/mise/config.toml
test -f /home/tester/.tmux.conf
# Neovim: fully managed LazyVim config (nothing cloned)
test -f /home/tester/.config/nvim/init.lua
test -f /home/tester/.config/nvim/lua/config/lazy.lua
test -f /home/tester/.config/nvim/lua/plugins/theme.lua
# lazy.nvim sync actually installed LazyVim and the theme
test -d /home/tester/.local/share/nvim/lazy/LazyVim
test -d /home/tester/.local/share/nvim/lazy/gruvbox-material
# the config loads without startup errors
load_log="$(su tester -c "nvim --headless '+lua vim.print(\"nvim-ok\")' +qa" 2>&1 || true)"
printf '%s\n' "$load_log" | grep -q 'nvim-ok'
if printf '%s\n' "$load_log" | grep -qE 'E5113|Error detected|Failed to load'; then
    echo "ERROR: Neovim config failed to load:" >&2
    printf '%s\n' "$load_log" >&2
    exit 1
fi
# the managed theme must actually be the active one
theme_log="$(su tester -c "nvim --headless '+lua print([[colors=]] .. tostring(vim.g.colors_name))' +qa" 2>&1 || true)"
if ! printf '%s\n' "$theme_log" | grep -q 'colors=gruvbox-material'; then
    echo "ERROR: active colorscheme is not gruvbox-material:" >&2
    printf '%s\n' "$theme_log" >&2
    exit 1
fi
# The picker must be telescope, not the v16 default (snacks.picker): that is
# what makes every <leader>f* key use the telescope spec from lua/plugins.
picker_log="$(su tester -c "nvim --headless '+lua local p = require([[lazyvim.util.pick]]).picker; print([[picker=]] .. (p and p.name or [[none]]))' +qa" 2>&1 || true)"
if ! printf '%s\n' "$picker_log" | grep -q 'picker=telescope'; then
    echo "ERROR: LazyVim picker is not telescope:" >&2
    printf '%s\n' "$picker_log" >&2
    exit 1
fi
test -f /home/tester/.local/bin/chezmoi
pacman -Qi fish tmux >/dev/null
su tester -c "fish -c 'echo fish-runs'"

pinned_go="$(tool_pin go)"
pinned_nvim="$(tool_pin neovim)"
echo "pinned: go=${pinned_go} neovim=${pinned_nvim}"
if [ -n "$pinned_go" ] && [ "$pinned_go" != "latest" ]; then
    test "$(/usr/local/bin/go env GOVERSION)" = "go${pinned_go}"
fi
if [ -n "$pinned_nvim" ] && [ "$pinned_nvim" != "latest" ]; then
    # No `| head -1` pipeline: nvim keeps writing, head exits, SIGPIPE -> 141.
    nvim_version="$(su tester -c "fish -c 'nvim --version'")"
    case "$nvim_version" in
    *"v${pinned_nvim}"*) ;;
    *)
        echo "ERROR: pinned neovim v${pinned_nvim} not installed:" >&2
        printf '%s\n' "$nvim_version" >&2
        exit 1
        ;;
    esac
fi

# Rust comes from mise's rustup backend with an explicit component list. The
# rust-analyzer component is what stops the rustup proxy from recursing into
# mise's shim ("fallback recursion detected"), so assert both.
rustc_version="$(su tester -c "fish -c 'rustc --version'")"
case "$rustc_version" in
rustc\ 1.*) ;;
*)
    echo "ERROR: rustc is not available: '$rustc_version'" >&2
    exit 1
    ;;
esac
su tester -c "fish -c 'rust-analyzer --version'" | grep 'rust-analyzer' >/dev/null || {
    echo "ERROR: rust-analyzer does not run (component missing?)" >&2
    exit 1
}
su tester -c "fish -c 'rustup component list --installed'" | grep 'rust-analyzer' >/dev/null || {
    echo "ERROR: rust-analyzer component is not installed in the toolchain" >&2
    exit 1
}

echo "ARCH: ALL ASSERTIONS PASSED"
