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

## Declarative software

Everything installed is described in one file, `.chezmoidata/software.yaml`:

```yaml
software:
  go:
    version: "1.27.3"
    sha256:
      amd64: "65efbc80..."
      arm64: "a06e9930..."
  neovim:
    version: "0.12.6"

packages:
  debian:   [fish, tmux, git, curl, fzf, powerline, direnv, kitty-terminfo]
  arch:     [fish, tmux, git, curl, fzf, powerline, kitty-terminfo, neovim, direnv]
  raspbian: [fish, tmux, vim, git, curl, fzf, direnv]
```

The hooks are chezmoi templates (`run_*.sh.tmpl`), so this file is rendered
into each hook before it runs. Changing a value changes that hook's content
hash, which makes chezmoi re-run exactly that hook on the next `chezmoi apply`
and nothing else - declarative versioning with no extra tooling:

```bash
$EDITOR .chezmoidata/software.yaml   # bump go: "1.28.0" (and its sha256)
chezmoi apply                        # only the Go hook re-runs
```

`version: "latest"` opts a tool back into tracking upstream instead of pinning.

Limits worth knowing:

- **Arch** package versions are not pinned: pacman follows the rolling repos, so
  `packages.arch` is a list, not a lockfile. Exact pinning there needs an AUR
  snapshot, mise, or Nix.
- Go's `sha256` is per architecture: update both when bumping, or leave an entry
  empty and the digest is looked up from go.dev's release feed.
- Distro packages install whatever the repo currently ships; only the
  upstream-fetched tools (Go, Neovim) carry exact versions.

For fully declarative *system* management (every package and version locked,
plus rollbacks), the tool for that is Nix + Home Manager on top of this repo -
chezmoi would then only manage the few files Nix does not.

## Distro differences

Handled inside the scripts/templates, no per-distro bootstrap needed:

- **Ubuntu/Debian**: Neovim from the pinned GitHub release (apt's is ancient),
  Go from the official tarball at the pinned version with sha256 verification
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

Two separate things, on purpose:

**Changing what is installed / which version** - edit
`.chezmoidata/software.yaml` and `chezmoi apply`. Only the affected hook re-runs
(its rendered content changed).

**Re-running the hooks at the current pins** - `./update.sh` re-checks Go and
updates the plugin tooling (NvChad, tmux, fisher, Lazy). Installed toolchains
stay at their declared versions:

```bash
./update.sh            # Go re-check, NvChad, tmux/fish/nvim plugins
./update.sh --system   # also apt upgrade / pacman -Syu
```

`chezmoi apply` alone never re-runs an already-executed hook: chezmoi keys
`run_once_*` / `run_onchange_*` on the content hash, so an unchanged (rendered)
hook is skipped. `update.sh` re-runs them explicitly, and each self-checks
first, so it is safe and fast when current (Go re-check ~0.4s).

| Component | Update |
|-----------|--------|
| Go | bump `software.go.version` + sha256, `chezmoi apply` (or `./update.sh` to re-check the current pin) |
| Neovim | bump `software.neovim.version`, `chezmoi apply` |
| NvChad | `git -C ~/.config/nvim pull --ff-only`, also done by `./update.sh` |
| nvim plugins | `nvim --headless "+Lazy! update" +qa` |
| tmux plugins | `~/.tmux/plugins/tpm/bin/update_plugins all`, then `prefix + I` |
| fish plugins | `fish -c 'fisher update'` |
| system packages | `sudo apt-get update && sudo apt-get upgrade` / `sudo pacman -Syu` |
| Claude Code | self-updates in place |

To force **unchanged** hooks to re-run (blunt tool: also resets chezmoi's record
of which files were last written, so unmanaged local edits can be overwritten
without a prompt):

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
├── .chezmoidata/
│   └── software.yaml                # Declarative: packages + pinned versions
├── .chezmoiscripts/                 # All run_* hooks (chezmoi executes them;
│   │                                # not written to $HOME); *.tmpl render from
│   │                                # .chezmoidata/software.yaml
│   ├── run_once_before_*.sh[.tmpl]  # System packages, Neovim, NvChad
│   ├── run_once_after_*.sh          # TPM, Fisher, nvim plugins, Claude, Happier, VPNs
│   └── run_onchange_*.sh[.tmpl]     # Go toolchain, login shell
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
