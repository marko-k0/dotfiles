#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing system packages"
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm --needed fish tmux git curl fzf powerline kitty-terminfo neovim

echo "==> Installing chezmoi"
if command -v chezmoi &>/dev/null; then
  echo "    chezmoi already installed"
else
  sudo pacman -S --noconfirm --needed chezmoi || {
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
  }
fi

echo "==> Installing NvChad v2.0"
if [ -d "$HOME/.config/nvim/.git" ]; then
  echo "    NvChad already present"
else
  rm -rf "$HOME/.config/nvim"
  git clone --branch v2.0 --depth 1 https://github.com/NvChad/NvChad "$HOME/.config/nvim"
fi

echo "==> Applying dotfiles with chezmoi"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.config/chezmoi"
cat > "$HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "$DOTFILES_DIR"
EOF
chezmoi apply

echo "==> Installing TPM (Tmux Plugin Manager)"
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "    TPM already installed"
else
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

echo "==> Installing tmux plugins"
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

echo "==> Installing Fisher and Fish plugins"
fish -c '
  if not functions -q fisher
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
    fisher install jorgebucaran/fisher
  else
    fisher update
  end
'

echo "==> Bootstrapping Neovim plugins"
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "==> Installing Claude Code"
if command -v claude &>/dev/null; then
  echo "    Claude Code already installed"
else
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo "==> Installing Happier"
if command -v happier &>/dev/null; then
  echo "    happier already installed"
else
  HAPPIER_NONINTERACTIVE=1 curl -fsSL https://happier.dev/install | bash
fi

echo "==> Setting default shell to fish"
if [ "$SHELL" != "/usr/bin/fish" ]; then
  chsh -s /usr/bin/fish
  echo "    Default shell changed to fish (takes effect on next login)"
else
  echo "    Already using fish"
fi

echo ""
echo "==> Setup complete!"
echo ""
echo "Post-install steps:"
echo "  - Set OPENAI_API_KEY env var for codecompanion.nvim"
echo "  - Log out and back in for fish shell to take effect"
echo "  - Run 'tide configure' to set up the fish prompt theme"
echo "  - Run 'happier auth login --no-open' to authenticate (use --no-open over SSH)"
