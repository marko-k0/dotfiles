#!/bin/bash
# Full end-to-end test of this repo on a bare Ubuntu 24.04 container.
# Used by CI (.github/workflows/ci.yml) and runnable locally:
#   docker run --rm --network host -v "$PWD":/repo -w /repo \
#     ubuntu:24.04 bash /repo/.github/test/ubuntu.sh
# Runs as root: provisions a test user with passwordless sudo, runs
# init.sh as that user, then asserts the installed state.
set -euo pipefail

apt-get update -qq
apt-get install -y sudo git curl >/dev/null
useradd -m -s /bin/bash tester
echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== Running init.sh as tester ==="
su tester -c "HOME=/home/tester bash $REPO/init.sh" 2>&1 | tee /tmp/init.log

echo "=== All setup scripts must have run ==="
# claude/happier skip in CI (their installers 403 datacenter IPs)
for stage in packages neovim tmux fish nvim-plugins go shell; do
    grep -q "==> \[$stage\]" /tmp/init.log || {
        echo "ERROR: [${stage}] script never ran" >&2; exit 1;
    }
done
grep -q "\[claude\] CI environment detected" /tmp/init.log || {
    echo "ERROR: claude script did not hit its CI skip" >&2; exit 1;
}

echo "=== Assertions ==="
test -x /usr/local/go/bin/go
/usr/local/go/bin/go version
test -x /usr/bin/fish
test -x /usr/bin/direnv
test -f /home/tester/.config/fish/config.fish
fish -n /home/tester/.config/fish/config.fish
grep -q "/usr/local/go/bin" /home/tester/.config/fish/config.fish
test -f /home/tester/.tmux.conf
# nvim: the official GitHub build symlinked into /usr/local/bin
sudo test -x /usr/local/bin/nvim
/usr/local/bin/nvim --version | head -1
test -d /home/tester/.config/nvim/lua/custom
test -f /home/tester/.local/bin/chezmoi
su tester -c "fish -c 'echo fish-runs'"

echo "UBUNTU 24.04: ALL ASSERTIONS PASSED"
