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

- `run_once_before_*` scripts (in `.chezmoiscripts/`) run **before** dotfiles
  are written (system packages, Neovim + NvChad)
- dotfiles are written (templates branch on the distro via `.osRelease`)
- `run_once_after_*` scripts run **after** (TPM, Fisher, plugin syncs,
  Claude Code, Happier, Raspbian VPNs)
- `run_onchange_*` scripts run when their content changes (Go toolchain,
  login shell); both self-skip fast when already up to date

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
| `run_onchange_50_go.sh` | latest Go: tarball+sha256 on Ubuntu, pacman on Arch |
| `run_onchange_55_shell.sh` | fish as login shell |

Re-running `init.sh` (or `chezmoi apply`) is always safe: `run_once` scripts
re-run only when their content changes, and the `run_onchange` scripts skip
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

## Updating

`chezmoi apply` does **not** upgrade anything installed by the hooks. chezmoi
only executes `run_once_*` / `run_onchange_*` scripts when their *contents*
change (per content hash, so an unchanged hook never runs again), so upstream
releases are picked up by re-running the hooks:

```bash
./update.sh            # Go, Neovim/NvChad, tmux + fish + nvim plugins
./update.sh --system   # also apt upgrade / pacman -Syu
```

Each hook self-checks first, so this is safe and fast when already current (the
Go check costs ~0.4s when up to date). Individual pieces:

| Component | Update |
|-----------|--------|
| Go | `bash .chezmoiscripts/run_onchange_50_go.sh` (tarball+sha256 or pacman) |
| Neovim | `bash .chezmoiscripts/run_once_before_10_neovim.sh` (installs only if missing/older than 0.10) |
| NvChad | `git -C ~/.config/nvim pull --ff-only` |
| nvim plugins | `nvim --headless "+Lazy! update" +qa` |
| tmux plugins | `~/.tmux/plugins/tpm/bin/update_plugins all`, then `prefix + I` |
| fish plugins | `fish -c 'fisher update'` |
| system packages | `sudo apt-get update && sudo apt-get upgrade` / `sudo pacman -Syu` |
| Claude Code | self-updates in place |

To force **all** hooks to re-run from scratch (blunt tool: resets chezmoi's
record of which scripts ran, and of which files were last written — unmanaged
local edits can then be overwritten without a prompt):

```bash
chezmoi state delete-bucket --bucket=scriptState   # run_once_* re-run
chezmoi state delete-bucket --bucket=entryState    # run_onchange_* re-run
chezmoi apply
```

Editing a hook's content re-runs that hook on the next apply, which is the
intended way to change what a hook does.

## Repository structure

```
dotfiles/
├── init.sh                          # Only entry point: chezmoi + apply
├── update.sh                        # Re-run hooks: toolchains + plugins
├── .chezmoiscripts/                 # All run_* scripts (chezmoi executes them;
│   │                                # not written to $HOME)
│   ├── run_once_before_*.sh         # System packages, Neovim, NvChad
│   ├── run_once_after_*.sh          # TPM, Fisher, nvim plugins, Claude, Happier, VPNs
│   └── run_onchange_*.sh            # Go toolchain, login shell
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

## CI

GitHub Actions runs on every push/PR (plus a weekly scheduled run to catch
upstream breakage: new tool versions, URL rot):

- **lint** — shellcheck on all scripts, plus template render checks: the fish
  config is rendered for both the Ubuntu and Raspbian branches and parse-checked
  with `fish -n`, and `.chezmoiignore` is verified to deploy `.vimrc` only on
  Raspbian
- **ubuntu-2404 / archlinux** — full end-to-end: the exact `init.sh` a fresh
  machine would run, inside the official `ubuntu:24.04` / `archlinux:base-devel`
  containers, then assertions on the installed state (Go version, fish, nvim,
  direnv, tmux, NvChad, fish parse + startup)

Claude Code and Happier installers are skipped in CI (`DOTFILES_CI=1`):
claude.ai serves HTTP 403 to datacenter IPs, so that install can only be
verified on a real machine.

To run the same tests locally:

```bash
docker run --rm --network host -e DOTFILES_CI=1 -v "$PWD":/repo -w /repo \
  ubuntu:24.04 bash /repo/.github/test/ubuntu.sh
docker run --rm --network host -e DOTFILES_CI=1 -v "$PWD":/repo -w /repo \
  archlinux:base-devel bash /repo/.github/test/arch.sh
```
