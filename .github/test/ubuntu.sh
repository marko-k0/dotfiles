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
# Note: no `| head -1` here (or `grep -q` downstream): with pipefail, a consumer
# exiting early sends SIGPIPE to the producer and the pipeline returns 141.
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
# Hybrid mode: go is a real binary in /usr/local/bin (no shims, no mise)
test -x /usr/local/bin/go
/usr/local/bin/go version
test -x /usr/bin/fish
test -x /usr/bin/direnv
# fzf and neovim come from mise, not from apt
if dpkg -l fzf neovim 2>/dev/null | grep '^ii' >/dev/null; then
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
test -d /home/tester/.local/share/nvim/lazy/gruvbox-material
# one representative plugin per extra added in this branch
for p in mini.surround inc-rename.nvim vim-illuminate nvim-treesitter-context \
    SchemaStore.nvim helm-ls.nvim; do
    test -d "/home/tester/.local/share/nvim/lazy/$p"
done
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
# A failed lazy.nvim clone must exit headless instead of blocking on getchar():
# without a UI getchar() waits forever, which would stall `chezmoi apply`.
nvim_bin="$(su tester -c "fish -c 'command -v nvim'")"
rm -rf /tmp/nvim-hang
mkdir -p /tmp/nvim-hang/bin /tmp/nvim-hang/data
printf '#!/bin/sh\nexit 1\n' > /tmp/nvim-hang/bin/git
chmod -R 777 /tmp/nvim-hang
rc=0
su tester -c "XDG_CONFIG_HOME=/home/tester/.config XDG_DATA_HOME=/tmp/nvim-hang/data \
    PATH=/tmp/nvim-hang/bin:/usr/bin:/bin timeout 20 '$nvim_bin' --headless '+qa'" \
    >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 124 ]; then
    echo "ERROR: nvim hung when lazy.nvim could not be cloned" >&2
    exit 1
fi
if [ "$rc" -eq 0 ]; then
    echo "ERROR: expected a non-zero exit when the lazy.nvim clone fails" >&2
    exit 1
fi
echo "lazy.nvim clone failure exits cleanly (rc=${rc})"
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
if [ -n "$pinned_kubectl" ] && [ "$pinned_kubectl" != "latest" ]; then
    su tester -c "fish -c 'kubectl version --client'" | grep -F "v${pinned_kubectl}" >/dev/null
fi
# mise-managed CLI tools resolve through shims in a login shell
su tester -c "fish -c 'kind --version'" | grep 'kind version' >/dev/null
su tester -c "fish -c 'helm version --short'" | grep 'v' >/dev/null

# ops tooling: every declared mise tool must resolve through the shims
su tester -c "fish -c 'command -q istioctl; and command -q kubebuilder; and command -q yq; and command -q fortio; and command -q grpcurl; and command -q crane; and command -q k9s; and command -q stern; and command -q dlv; and command -q golangci-lint; and command -q kubens; and command -q kubectx; and command -q krew; and command -q pluto; and command -q kubeconform; and command -q kube-score; and command -q trivy; and command -q sloth'" || {
    echo "ERROR: one or more mise ops tools are not on PATH (istioctl kubebuilder yq fortio grpcurl crane k9s stern dlv golangci-lint kubens kubectx krew pluto kubeconform kube-score trivy sloth)" >&2
    exit 1
}
# distro diagnostics: binaries provided by the apt/pacman lists
for b in conntrack socat stress-ng iperf3 hping3 tree htop btop ncdu fio \
    tcpdump mtr iftop nmap lsof strace iotop sar ss ip perf df du ps vmstat; do
    command -v "$b" >/dev/null || {
        echo "ERROR: missing diagnostic tool: $b" >&2
        exit 1
    }
done

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

echo "UBUNTU 24.04: ALL ASSERTIONS PASSED"
