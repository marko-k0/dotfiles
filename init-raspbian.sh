#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y fish tmux git curl fzf

# kitty-terminfo may not be available on Raspbian
sudo apt-get install -y kitty-terminfo 2>/dev/null || true

# tmux-256color terminfo may be missing on older Raspbian
if ! infocmp tmux-256color &>/dev/null; then
    echo "==> Installing tmux-256color terminfo..."
    sudo apt-get install -y ncurses-term 2>/dev/null || true
fi

echo "==> Installing Neovim from source..."
if command -v nvim &>/dev/null && nvim --version | head -1 | grep -qE 'v0\.(1[0-9]|[2-9])'; then
    echo "    Neovim already installed: $(nvim --version | head -1)"
else
    sudo apt-get install -y ninja-build gettext cmake unzip curl build-essential
    rm -rf /tmp/neovim-build
    git clone --depth 1 --branch stable https://github.com/neovim/neovim /tmp/neovim-build
    cd /tmp/neovim-build
    make CMAKE_BUILD_TYPE=Release
    sudo make install
    cd -
    rm -rf /tmp/neovim-build
fi

echo "==> Setting up minimal Neovim config..."
mkdir -p "$HOME/.config/nvim"
if [ ! -f "$HOME/.config/nvim/init.lua" ]; then
    cat > "$HOME/.config/nvim/init.lua" <<'NVIM_EOF'
-- Minimal Neovim config for Raspbian

-- Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.mouse = "a"
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250

-- OSC 52 clipboard (works over SSH)
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}

-- Leader key
vim.g.mapleader = " "

-- Keymaps
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>")
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>")
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>")
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")
NVIM_EOF
fi

echo "==> Installing chezmoi..."
if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Setting up chezmoi..."
mkdir -p "$HOME/.config/chezmoi"
cat > "$HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "${REPO_DIR}"
EOF

echo "==> Applying dotfiles with chezmoi..."
export PATH="$HOME/.local/bin:$PATH"
chezmoi apply

echo "==> Installing TPM (Tmux Plugin Manager)..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

echo "==> Installing tmux plugins..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

echo "==> Installing Fisher and Fish plugins..."
fish -c '
    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
    else
        fisher update
    end
'

echo "==> Changing default shell to Fish..."
if [ "$SHELL" != "/usr/bin/fish" ]; then
    sudo chsh -s /usr/bin/fish "$USER"
fi

echo ""
echo "Done! Log out and back in for fish to become your default shell."
echo ""
echo "Post-install:"
echo "  - Create ~/.config/fish/secrets.fish with your env vars"
echo "  - Run 'tmux' and press prefix+I to verify tmux plugins"
