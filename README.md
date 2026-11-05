# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Quick start

```bash
git clone git@github.com:marko-k0/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
bash init.sh
```

That's the only entry point, for every supported distro (Ubuntu 24.04, Arch,
Raspbian). `init.sh` installs curl (if missing) and chezmoi, points chezmoi at
the checkout, and runs `chezmoi apply`. Everything else happens inside chezmoi:

- `run_once_before_*` scripts run **before** dotfiles are written
  (system packages, Neovim + NvChad)
- dotfiles are written (templates branch on the distro via `.osRelease`)
- `run_once_after_*` scripts run **after** (TPM, Fisher, plugin syncs,
  Claude Code, Happier, Raspbian VPNs)
- `run_on_change_*` scripts run on **every** apply but exit fast when
  already up to date (Go toolchain, login shell)

| Script | What |
|--------|------|
| `run_once_before_00_packages.sh` | fish, tmux, fzf, powerline, kitty-terminfo (apt / pacman; lighter set on Raspbian) |
| `run_once_before_10_neovim.sh` | latest Neovim (GitHub build on Ubuntu, pacman on Arch) + NvChad v2.0 |
| `run_once_after_00_tmux.sh` | TPM + tmux plugins |
| `run_once_after_10_fish.sh` | Fisher + fish plugins |
| `run_once_after_20_nvim_plugins.sh` | headless `Lazy! sync` |
| `run_once_after_30_claude.sh` | Claude Code |
| `run_once_after_40_happier.sh` | Happier |
| `run_once_after_50_vpn.sh` | Tailscale + NordVPN (Raspbian only) |
| `run_on_change_50_go.sh` | latest Go: tarball+sha256 on Ubuntu, pacman on Arch |
| `run_on_change_55_shell.sh` | fish as login shell |

Re-running `init.sh` (or `chezmoi apply`) is always safe: `run_once` scripts
re-run only when their content changes, and the `run_on_change` scripts skip
themselves when up to date.

## Distro differences

Handled inside the scripts/templates, no per-distro bootstrap needed:

- **Ubuntu/Debian**: Neovim from GitHub (apt's is ancient), Go from the
  official tarball with sha256 verification (apt lags upstream)
- **Arch**: pacman for everything (tracks upstream closely)
- **Raspbian**: lighter package set (vim, no powerline), minimal fish config
  (old fish), `dot_vimrc` deployed via a templated `.chezmoiignore` rule,
  no NvChad/Go/Claude/Happier

## What's included

- **Fish shell** - Vi mode, Tide prompt, fzf integration, git aliases
- **Neovim** - NvChad v2.0 with Gruvbox theme, LSP, Copilot, codecompanion, DAP debugging
- **Tmux** - Powerline status bar, vim-style navigation, clipboard integration
- **Kitty** - Gruvbox Dark Soft theme, custom tab bar

### Neovim plugins

Rust (rustaceanvim, crates.nvim, rust.vim), Go (go.nvim, gopls), Copilot, codecompanion, Telescope, Aerial, Neogit, nvim-dap, maximize.nvim

## Post-install

- Log out and back in for fish shell to take effect
- Run `tide configure` to set up the fish prompt
- Set `OPENAI_API_KEY` environment variable for codecompanion.nvim

## Repository structure

```
dotfiles/
├── init.sh                          # Only entry point: chezmoi + apply
├── run_once_before_*.sh             # System packages, Neovim, NvChad
├── run_once_after_*.sh              # TPM, Fisher, nvim plugins, Claude, Happier, VPNs
├── run_on_change_*.sh               # Go toolchain, login shell
├── dot_tmux.conf                    # ~/.tmux.conf
├── dot_tmux.conf.common             # ~/.tmux.conf.common
├── dot_vimrc                        # ~/.vimrc (Raspbian only, via .chezmoiignore)
├── private_dot_config/
│   ├── kitty/                       # ~/.config/kitty/
│   ├── nvim/lua/custom/             # ~/.config/nvim/lua/custom/ (NvChad customizations)
│   └── private_fish/                # ~/.config/fish/ (config.fish is a template)
├── private_dot_ssh/
│   └── executable_rc                # ~/.ssh/rc (SSH agent forwarding)
└── .chezmoiignore                   # Exclusions (templated: .vimrc only on Raspbian)
```

### Chezmoi naming conventions

| Prefix | Meaning |
|--------|---------|
| `dot_` | Maps to `.` (e.g. `dot_tmux.conf` -> `~/.tmux.conf`) |
| `private_` | Restricted file permissions (0600/0700) |
| `executable_` | File is made executable (0755) |
| `.tmpl` | Template, rendered at apply time |

## Manual usage

```bash
# Preview changes before applying
chezmoi diff

# Apply dotfiles
chezmoi apply

# Edit a managed file (opens source, applies on save)
chezmoi edit ~/.tmux.conf

# Render a template as chezmoi would (for testing)
chezmoi execute-template < private_dot_config/private_fish/config.fish.tmpl
```
