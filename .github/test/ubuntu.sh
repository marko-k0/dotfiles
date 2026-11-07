#!/bin/bash
# Full end-to-end test of this repo on a bare Ubuntu 24.04 container.
# Used by CI (.github/workflows/ci.yml) and runnable locally:
#   docker run --rm --network host -v "$PWD":/repo -w /repo \
#     ubuntu:24.04 bash /repo/.github/test/ubuntu.sh
# Runs as root: provisions a test user with passwordless sudo, runs
# init.sh as that user, then asserts the installed state.
set -euo pipefail

# Containers ship their own /etc/gai.conf. Mirror the host workaround: on
# networks where IPv6 to dl.google.com and sigstore TUF fails, downloads 404.
# No-op on IPv4-only runners (GitHub Actions).
grep -qE '^precedence[[:space:]]+::ffff:0:0/96' /etc/gai.conf 2>/dev/null \
    || echo 'precedence ::ffff:0:0/96 100' >> /etc/gai.conf

apt-get update -qq
apt-get install -y sudo git curl >/dev/null
useradd -m -s /bin/bash tester
echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DATA="$REPO/.chezmoidata/software.yaml"

# Read a pinned version for a mise tool from the data file.
tool_pin() {
    sed -n '/^  tools:/,/^[a-z]/p' "$DATA" \
        | grep -E "^    \"?$1\"?:" | head -1 \
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
# Hybrid mode: go is a real binary in /usr/local/bin (no shims, no mise)
test -x /usr/local/bin/go
/usr/local/bin/go version
test -x /usr/bin/fish
test -x /usr/bin/direnv
# fzf and neovim come from mise, not from apt
if dpkg -l fzf neovim 2>/dev/null | grep -q '^ii'; then
    echo "ERROR: fzf/neovim should be mise-managed, not apt-installed" >&2; exit 1
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
test -d /home/tester/.local/share/nvim/lazy/gruvbox.nvim
# the config loads without startup errors
load_log="$(su tester -c "nvim --headless '+lua vim.print(\"nvim-ok\")' +qa" 2>&1 || true)"
printf '%s\n' "$load_log" | grep -q 'nvim-ok'
if printf '%s\n' "$load_log" | grep -qE 'E5113|Error detected|Failed to load'; then
    echo "ERROR: Neovim config failed to load:" >&2
    printf '%s\n' "$load_log" >&2
    exit 1
fi
test -f /home/tester/.local/bin/chezmoi
su tester -c "fish -c 'echo fish-runs'"

# Declared versions must actually be installed (read from the data file, so a
# stale pin fails CI instead of silently installing whatever upstream ships).
pinned_go="$(tool_pin go)"
pinned_nvim="$(tool_pin neovim)"
pinned_kubectl="$(tool_pin kubectl)"
echo "pinned: go=${pinned_go} neovim=${pinned_nvim} kubectl=${pinned_kubectl}"
if [ -n "$pinned_go" ] && [ "$pinned_go" != "latest" ]; then
    test "$(/usr/local/bin/go env GOVERSION)" = "go${pinned_go}"
fi
if [ -n "$pinned_nvim" ] && [ "$pinned_nvim" != "latest" ]; then
    su tester -c "fish -c 'nvim --version'" | head -1 | grep -qF "v${pinned_nvim}"
fi
if [ -n "$pinned_kubectl" ] && [ "$pinned_kubectl" != "latest" ]; then
    su tester -c "fish -c 'kubectl version --client'" | grep -qF "v${pinned_kubectl}"
fi
# mise-managed CLI tools resolve through shims in a login shell
su tester -c "fish -c 'kind --version'" | grep -q 'kind version'
su tester -c "fish -c 'helm version --short'" | grep -q 'v'

echo "UBUNTU 24.04: ALL ASSERTIONS PASSED"
