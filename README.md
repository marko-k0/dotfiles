# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## What's included

- **Fish shell** - Vi mode, Tide prompt, fzf integration, git aliases
- **Neovim** - NvChad v2.0 with Gruvbox theme, LSP, Copilot, codecompanion, DAP debugging
- **Tmux** - Powerline status bar, vim-style navigation, clipboard integration
- **Kitty** - Gruvbox Dark Soft theme, custom tab bar

### Neovim plugins

Rust (rustaceanvim, crates.nvim, rust.vim), Go (go.nvim, gopls), Copilot, codecompanion, Telescope, Aerial, Neogit, nvim-dap, maximize.nvim

## Quick start

```bash
git clone git@github.com:marko-k0/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles

# Ubuntu / Debian
bash init-ubuntu.sh

# Arch Linux
bash init-arch.sh
```

The init script will install all dependencies, apply dotfiles, and set fish as the default shell.

## Post-install

- Log out and back in for fish shell to take effect
- Run `tide configure` to set up the fish prompt
- Set `OPENAI_API_KEY` environment variable for codecompanion.nvim

## Repository structure

```
dotfiles/
├── init-ubuntu.sh                   # Ubuntu/Debian setup script
├── init-arch.sh                     # Arch Linux setup script
├── dot_tmux.conf                    # ~/.tmux.conf
├── dot_tmux.conf.common             # ~/.tmux.conf.common
├── private_dot_config/
│   ├── kitty/                       # ~/.config/kitty/
│   ├── nvim/lua/custom/             # ~/.config/nvim/lua/custom/ (NvChad customizations)
│   └── private_fish/                # ~/.config/fish/
├── private_dot_ssh/
│   └── executable_rc                # ~/.ssh/rc (SSH agent forwarding)
└── .chezmoiignore                   # Files excluded from chezmoi apply
```

### Chezmoi naming conventions

| Prefix | Meaning |
|--------|---------|
| `dot_` | Maps to `.` (e.g. `dot_tmux.conf` -> `~/.tmux.conf`) |
| `private_` | Restricted file permissions (0600/0700) |
| `executable_` | File is made executable (0755) |

## Manual usage

```bash
# Preview changes before applying
chezmoi diff

# Apply dotfiles
chezmoi apply

# Edit a managed file (opens source, applies on save)
chezmoi edit ~/.tmux.conf
```
