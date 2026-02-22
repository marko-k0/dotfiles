#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y fish tmux vim git curl fzf

# kitty-terminfo may not be available on Raspbian
sudo apt-get install -y kitty-terminfo 2>/dev/null || true

# tmux-256color terminfo may be missing on older Raspbian
if ! infocmp tmux-256color &>/dev/null; then
    echo "==> Installing tmux-256color terminfo..."
    sudo apt-get install -y ncurses-term 2>/dev/null || true
fi

echo "==> Setting up Vim config..."
if [ ! -f "$HOME/.vimrc" ]; then
    cat > "$HOME/.vimrc" <<'VIMRC_EOF'
" Minimal Vim config for Raspbian

set number
set relativenumber
set expandtab
set shiftwidth=2
set tabstop=2
set smartindent
set ignorecase
set smartcase
set mouse=a
set signcolumn=yes
set updatetime=250
set incsearch
set hlsearch
set hidden
set noswapfile
set backspace=indent,eol,start
set laststatus=2
set wildmenu

" Colors
if has('termguicolors')
  set termguicolors
endif
syntax on

" Leader key
let mapleader = " "

" Keymaps
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <Esc> :noh<CR>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" OSC 52 clipboard (works over SSH)
if has('clipboard') || has('xterm_clipboard')
  set clipboard=unnamedplus
else
  " Manual OSC 52 yank for Vim 8.x without clipboard support
  function! OscYank() abort
    let text = getreg('"')
    let encoded = system('printf ' . shellescape(text) . ' | base64 | tr -d "\n"')
    call writefile(["\x1b]52;c;" . encoded . "\x07"], '/dev/stderr', 'b')
  endfunction
  augroup osc52
    autocmd!
    autocmd TextYankPost * call OscYank()
  augroup END
endif
VIMRC_EOF
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

echo "==> Writing minimal Fish config (Fish 3.1 compatible)..."
# The chezmoi-deployed config.fish uses fish_add_path and plugins that
# require Fish 3.4+. Raspbian 11 ships Fish 3.1.2, so we override with
# a minimal compatible config.
cat > "$HOME/.config/fish/config.fish" <<'FISH_EOF'
if status is-interactive
    fish_vi_key_bindings
    refresh_tmux_vars
    user_key_bindings

    alias g='git'
    alias k='kubectl'
    alias vim='vim'

    set -gx EDITOR vim
    set -gx VISUAL vim
end

set -x GOPATH $HOME/go

# fish_add_path not available in Fish < 3.2, use set -gx PATH instead
for p in $GOPATH/bin $HOME/.krew/bin $HOME/.cargo/bin $HOME/.local/bin
    if test -d $p; and not contains $p $PATH
        set -gx PATH $p $PATH
    end
end
FISH_EOF

# Remove fish_plugins to prevent Fisher from installing incompatible plugins
rm -f "$HOME/.config/fish/fish_plugins"

# Remove any tide/fzf.fish files that chezmoi may have deployed
rm -rf "$HOME/.config/fish/conf.d/fzf.fish" \
       "$HOME/.config/fish/functions/fzf_configure_bindings.fish" \
       "$HOME/.config/fish/functions/_fzf_"* \
       "$HOME/.config/fish/functions/fish_prompt.fish" \
       "$HOME/.config/fish/functions/_tide_"* \
       "$HOME/.config/fish/functions/tide.fish" \
       "$HOME/.config/fish/conf.d/_tide_"*

echo "==> Installing Tailscale..."
if ! command -v tailscale &>/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi

echo "==> Installing NordVPN..."
if ! command -v nordvpn &>/dev/null; then
    sh -c "$(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)"
fi

echo "==> Installing TPM (Tmux Plugin Manager)..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

echo "==> Installing tmux plugins..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

echo "==> Changing default shell to Fish..."
if [ "$SHELL" != "/usr/bin/fish" ]; then
    sudo chsh -s /usr/bin/fish "$USER"
fi

echo ""
echo "Done! Log out and back in for fish to become your default shell."
echo ""
echo "Post-install:"
echo "  - Run 'tmux' and press prefix+I to verify tmux plugins"
echo "  - Run 'sudo tailscale up' to connect to your tailnet"
echo "  - Run 'nordvpn login' and 'nordvpn connect' to set up NordVPN"
