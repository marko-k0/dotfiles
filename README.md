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

- `run_once_before_*` scripts run **before** dotfiles are written (distro
  packages, Neovim migration cleanup)
- dotfiles are written (templates branch on the distro via `.osRelease`)
- `run_after_05_mise.sh` installs the mise-managed tools (runs on every apply,
  ~20ms no-op) and links selected ones into `/usr/local/bin`
- `run_after_*` scripts run on **every** apply, after dotfiles: mise tools, and
  TPM (`~60ms` no-op) so adding a `@plugin` line to `~/.tmux.conf` installs it
  without touching any script
- `run_once_after_*` scripts run **after** once (Fisher, plugin syncs,
  Claude Code, Happier, Raspbian VPNs)
- `run_once_*` scripts re-run when their content changes (login shell)

| Script | What |
|--------|------|
| `run_once_before_00_packages.sh.tmpl` | distro packages from `software.yaml` (apt / pacman; lighter set on Raspbian) |
| `run_once_before_20_lazyvim.sh` | migrate away from an old NvChad config (nothing is cloned; `~/.config/nvim` is fully managed) |
| `run_after_05_mise.sh.tmpl` | `mise install` + global symlinks for `global_tools` |
| `run_after_00_tmux.sh` | TPM + tmux plugins, every apply (picks up new `@plugin` lines) |
| `run_once_after_10_fish.sh` | Fisher + fish plugins |
| `run_once_after_20_nvim_plugins.sh` | headless `Lazy! sync` |
| `run_once_after_30_claude.sh` | Claude Code |
| `run_once_after_40_happier.sh` | Happier |
| `run_once_after_50_vpn.sh` | Tailscale + NordVPN (Raspbian only) |
| `run_onchange_55_shell.sh` | fish as login shell |

Re-running `init.sh` (or `chezmoi apply`) is always safe: `run_once` scripts
re-run only when their content changes, and the mise hook reconciles state.

## Verify an install

```bash
go version                              # pinned binary, symlinked as /usr/local/bin/go
mise ls                                 # tools and the pins they came from
mise which nvim && nvim --version       # shim -> versioned install
fish -c 'kubectl version --client'      # shims resolve inside fish (incl. fish -c)
git -C ~/.config/nvim status                # config is chezmoi-managed (no clone)
nvim --headless '+lua print(vim.g.colors_name)' +qa   # gruvbox-material (LazyVim)
./update.sh                             # should finish with "done: everything up to date"
```

## Declarative software

Everything installed is described in one file, `.chezmoidata/software.yaml`:

```yaml
mise:
  install_mode: hybrid          # user | hybrid | all
  global_tools: [go]            # symlinked into /usr/local/bin (hybrid)
  global_link_dir: /usr/local/bin
  tools:
    go: "1.27.3"
    neovim: "0.12.6"
    fzf: "0.74.5"
    kubectl: "1.37.2"
    kind: "0.33.0"
    helm: "4.3.1"
    kubectx: "0.11.0"           # also provides kubens
    oh-my-posh: "31.3.0"
    uv: "0.12.23"
    "aqua:cilium/cilium-cli": "0.20.2"
    rust:                       # table spec: version + rustup options
      version: "1.97.0"
      profile: minimal          # no rust-docs; ~750 MB instead of ~1.6 GB
      components: [rust-analyzer, rust-src, rustfmt, clippy]

packages:
  debian:   [fish, tmux, git, curl, powerline, direnv, kitty-terminfo]
  arch:     [fish, tmux, git, curl, powerline, kitty-terminfo, direnv]
  raspbian: [fish, tmux, vim, git, curl, fzf, direnv]
```

**Which list a tool belongs in.** Distro packages when the tool needs system
integration (login shell, terminfo, daemons, PAM, `/etc` files), sits in a
prompt hot path, or is a security primitive whose distro backports matter
(git, curl). Everything else that ships release binaries goes to mise. A tool
may appear in only one list; CI enforces that for debian and arch.

**How tools are exposed** (`mise.install_mode`):

| mode | behaviour |
|---|---|
| `user` | tools live in `~/.local/share/mise`, reachable through mise shims only |
| `hybrid` (default) | as `user`, plus tools in `global_tools` are symlinked as real binaries into `global_link_dir` |
| `all` | every mise tool is symlinked into `global_link_dir` |

In `hybrid` mode `/usr/local/bin/go` points straight at the versioned binary,
so scripts, systemd, `sudo` and GUI-launched editors see Go with no shim
overhead. Switching modes is a one-line edit in the data file; the next apply
re-runs the hook and links (or stops linking) accordingly.

mise's own `install --system` is deliberately not used: `core:go` rejects it
("automatic system installation currently supports binary-download backends
only" on mise 2026.11.2), and symlinking the user-store binary gives the same
global visibility without needing `/etc/mise/config.toml`.

**Tool options (table specs).** A tool value can be a table instead of a version
string; it is rendered into `config.toml` as a TOML inline table, so every option
the backend supports is available:

```toml
"rust" = { version = "1.97.0", profile = "minimal", components = ["rust-analyzer", "rust-src", "rustfmt", "clippy"] }
```

Rust needs this form: `rust-analyzer` is not part of rustup's minimal profile, and
without the component the rustup proxy in `~/.cargo/bin` falls back into mise's
shim for the same name and recurses (see Troubleshooting). `rustfmt` and `clippy`
are explicit for the same reason — the minimal profile omits them, and the repo
format-on-save autocmd needs `rustfmt`.

**Bumping a version** is a data edit:

```bash
$EDITOR .chezmoidata/software.yaml   # go: "1.27.3" -> "1.28.0"
chezmoi apply                        # renders config.toml, installs, re-links
```

`version: "latest"` opts a single tool back into tracking upstream.

**Project-level pins still work, with one wrinkle.** mise resolves versions per
directory, so a repo with its own `mise.toml` overrides the pinned version inside
an interactive shell (fish activates the shims). The `/usr/local/bin` symlink,
however, always points at the globally pinned binary, which is what scripts,
systemd and `sudo` see. That split is intentional: interactive shells can switch
versions, everything else gets a stable floor.

**Not managed here:** `docker`. It comes from Docker's own apt repository
(`docker-ce`, containerd, buildx and compose plugins) plus a daemon, a systemd
unit and the `docker` group. Declaring distro `docker.io` would replace that
setup, and mise cannot manage a daemon. It is left as a documented follow-up.

## Distro differences

Handled inside the scripts/templates, no per-distro bootstrap needed:

- **Ubuntu/Debian**: mise provides Neovim, fzf and the CLI tools (apt's are old)
- **Arch**: same, because mise owns those tools on both distros; pacman only
  installs the system-integrated set
- **Raspbian**: lighter package set (vim, no powerline), minimal fish config
  (old fish), `dot_vimrc` deployed via a templated `.chezmoiignore` rule,
  no Neovim/mise/Claude/Happier

## What's included

- **Fish shell** - Vi mode, Tide prompt, fzf integration, git aliases
- **Neovim** - LazyVim with the gruvbox-material theme, LSP, Copilot, codecompanion, DAP debugging
- **Tmux** - Powerline status bar, prefix + `<C-h/j/k/l>` navigation that also moves between Neovim splits, clipboard integration
- **Kitty** - Gruvbox Dark Soft theme, custom tab bar

### Neovim plugins

Rust (rustaceanvim, crates.nvim), Go (gopls, goimports/gofumpt, delve),
Docker/Kubernetes YAML/Helm/JSON (`lang.docker`, `lang.yaml`, `lang.helm`,
`lang.json`), Copilot, codecompanion, Telescope, Aerial, Neogit, nvim-dap,
maximize.nvim, and vim-tmux-navigator (seamless `<C-h/j/k/l>` between splits and
tmux panes; the tmux half is a TPM plugin in `dot_tmux.conf`).

Quality-of-life extras: `coding.mini-surround` (`gsa`/`gsd`/`gsr`), `editor.inc-rename`
(live rename preview via `<leader>cr`), `editor.illuminate` (highlight other
references) and `ui.treesitter-context` (sticky function/block header).

The fuzzy finder is **telescope** with the ivy layout. `lua/config/options.lua`
sets `vim.g.lazyvim_picker = "telescope"`; it must live there rather than in
`init.lua`, because LazyVim's own `options.lua` (which sets `"auto"`) loads
first and the choice has to be in place before the extras are resolved. Since
LazyVim v16 the default is `snacks.picker`, and a telescope spec that is not
selected that way gets installed but never registered (so keymaps would quietly
use snacks). Remove that line, and the telescope spec in
`lua/plugins/editor.lua`, to go back to snacks.

Moving inside a picker (telescope defaults, nothing custom): typing filters,
`<C-n>`/`<C-p>` move the selection, `j`/`k` work in normal mode, `<Tab>`/`<S-Tab>`
multi-select.

The config is plain files managed by chezmoi (`init.lua`, `lua/config/*.lua`,
`lua/plugins/*.lua`); there is no upstream starter clone. `lua/config/lazy.lua`
clones lazy.nvim on first start, and the `run_once_after_20_nvim_plugins.sh` hook
runs a headless `Lazy! sync` so a fresh machine comes up with every plugin.

## Post-install

- Log out and back in for fish shell to take effect
- Run `tide configure` to set up the fish prompt
- Set `OPENAI_API_KEY` environment variable for codecompanion.nvim
- Start `nvim` once interactively: the headless plugin sync in the apply hook
  installs LazyVim and the plugins, but Mason's tool downloads (LSP servers,
  debug adapters) are background jobs that outlive that headless run. They
  finish on the first interactive start, where Mason shows progress

## Updating

**Changing what is installed, or which version** - edit
`.chezmoidata/software.yaml` and run `chezmoi apply`. It renders
`~/.config/mise/config.toml`, installs or removes tools, and re-links the
global symlinks. Versions are pins, not drift: nothing moves unless you change
a pin (or declare `"latest"` for a tool).

**Refreshing mise, plugins and helper tooling** - `./update.sh`:

```bash
./update.sh            # mise self-update + upgrade + lockfile + plugin updates
./update.sh --system   # also apt upgrade / pacman -Syu
```

| Component | Update |
|-----------|--------|
| mise itself | `mise self-update` (run by `./update.sh`) |
| go, neovim, fzf, kubectl, kind, helm, kubectx, oh-my-posh, uv, cilium, rust | bump the pin in `software.yaml`, then `chezmoi apply` |
| LazyVim + nvim plugins | `nvim --headless "+Lazy! update" +qa` (also `./update.sh`) |
| tmux plugins | `~/.tmux/plugins/tpm/bin/update_plugins all`, then `prefix + I` |
| fish plugins | `fish -c 'fisher update'` |
| system packages | `sudo apt-get update && sudo apt-get upgrade` / `sudo pacman -Syu` |
| Claude Code | self-updates in place |

### Lockfile

`~/.config/mise/mise.lock` is generated by `mise lock --global` and is
machine-local, not managed by chezmoi (managing it would cause permanent drift
after every regeneration).

- Regenerate: `mise lock --global`, also run by `./update.sh`
- Used automatically by `mise install`; `mise install --locked` fails if an
  artifact is not in the lockfile
- It adds per-platform sha256 and download URLs. Exact versions already come
  from `config.toml`, so losing it costs checksum reproducibility, not pins.

`~/.config/nvim/lazy-lock.json` is the equivalent for Neovim: written by
lazy.nvim on every sync/update, machine-local and likewise not managed by
chezmoi. Commit-worthy if you ever want identical plugin revisions across
machines; deleting it only means the next sync resolves plugins fresh.

### One owner per tool

A tool lives in `packages:` or in `mise.tools:`, never both; CI enforces that
for debian and arch. When a tool moves to mise, remove the hand-installed copy
so two versions cannot shadow each other:

```bash
type -p kubectl kind helm cilium uv oh-my-posh   # should be mise or /usr/local/bin
rm ~/.local/bin/kubectl ~/.local/bin/kind         # after checking each one
```

The mise hook warns about any legacy copy it finds on `PATH`.

### Migrating from the previous setup

**If you already have a global mise config, merge it first.** This repo now
manages `~/.config/mise/config.toml`, and `chezmoi apply` replaces that file
when it exists and is unmanaged (no prompt, unlike files chezmoi wrote itself).
Check before applying:

```bash
ls -l ~/.config/mise/                     # does config.toml already exist?
mise ls                                   # what is installed
```

Any pin that only lives there (and is not in `.chezmoidata/software.yaml`) will
be dropped from the config by the apply. Add it to the `mise.tools:` map first,
then apply. Installed versions stay in `~/.local/share/mise` either way; it is
the pins, not the binaries, that would be lost.

Earlier versions of this repo installed Go into `/usr/local/go` and Neovim into
`/opt/nvim-linux-*`, and CLI tools were hand-installed into `~/.local/bin`.
mise owns those now, so remove the old copies after the first apply.

These lines work in both bash and fish. Avoid a bare `/opt/nvim-linux-*` glob in
fish: an unmatched wildcard is a hard error there and aborts the **whole**
command line, so the other removals would silently not run.

```bash
# old Go toolchain, and the PATH line the old hook appended to ~/.profile
sudo rm -rf /usr/local/go
grep -n '/usr/local/go/bin' ~/.profile      # delete that line if present

# old Neovim build (find -exec works in both shells)
sudo rm -rf /usr/local/bin/nvim
sudo find /opt -maxdepth 1 -name 'nvim-linux-*' -exec rm -rf {} +

# hand-installed CLIs now provided by mise
type -p kubectl kind helm cilium uv oh-my-posh nvim fzf
rm -f ~/.local/bin/{kubectl,kind,helm,cilium,uv,uvx,oh-my-posh,nvim}
```

Then confirm the leftovers are gone and mise is in charge:

```bash
ls -d /usr/local/go 2>/dev/null || echo "no system Go"
mise which go                    # real binary under ~/.local/share/mise/installs/
command -v go                    # shim in fish, /usr/local/bin/go in bash/systemd
```

`command -v go` must not print `/usr/local/go/bin/go`: that path means an old
toolchain is still earlier in `PATH` (typically from a stale `~/.profile` line).
Note that `readlink -f` on a mise shim resolves to the mise *binary*, not to Go;
use `mise which go` to see the actual toolchain.

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

### Migrating from NvChad to LazyVim

Neovim's config used to be an NvChad clone with a small `lua/custom` layer. It is
now plain chezmoi-managed files, so `~/.config/nvim` is no longer a git repo and
the plugin set comes from LazyVim plus `lua/plugins/*.lua`.

The first apply handles the switch automatically
(`run_once_before_20_lazyvim.sh`):

- an existing non-LazyVim `~/.config/nvim` is **moved** to
  `~/.config/nvim.bak-<timestamp>` (never deleted)
- NvChad leftovers in the data dir (`nvim/nvchad`, `lazy/base46`, `lazy/ui`,
  `lazy/nvterm`, `lazy/nvim-colorizer.lua`) are moved to
  `~/.local/share/nvim/pre-lazyvim-<timestamp>/`. This matters: a stale base46
  cache is what makes NvChad configs fail with
  `cannot open .../nvim/nvchad/base46/defaults`

Behaviour changes worth knowing:

| Before (NvChad) | Now (LazyVim) |
|---|---|
| `git -C ~/.config/nvim pull` | nothing to pull: `./update.sh` updates plugins |
| nvim-tree (`<leader>e`) | LazyVim's explorer on the same key |
| go.nvim | LazyVim's `lang.go` extra: gopls, goimports/gofumpt, delve, neotest |
| rust.vim + rustfmt autosave | rustaceanvim + a `BufWritePre` rustfmt autocmd |
| Gruvbox with transparency | gruvbox-material, transparent (`lua/plugins/theme.lua`) |
| OSC 52 clipboard | same (`lua/config/options.lua`) |

Old NvChad config still available for reference:
`~/.config/nvim.bak-<timestamp>`. Delete it once you are happy.

## Repository structure

```
dotfiles/
├── init.sh                          # Only entry point: chezmoi + apply
├── update.sh                        # Re-run hooks: toolchains + plugins
├── .chezmoidata/
│   └── software.yaml                # Declarative: mise tools + distro packages
├── .chezmoiscripts/                 # All run_* hooks (chezmoi executes them;
│   │                                # not written to $HOME); *.tmpl render from
│   │                                # .chezmoidata/software.yaml
│   ├── run_once_before_*.sh[.tmpl]  # distro packages, Neovim migration
│   ├── run_after_05_mise.sh.tmpl    # mise install + global symlinks
│   ├── run_once_after_*.sh          # TPM, Fisher, nvim plugins, Claude, Happier, VPNs
│   └── run_onchange_*.sh            # login shell
├── dot_tmux.conf                    # ~/.tmux.conf
├── dot_tmux.conf.common             # ~/.tmux.conf.common
├── dot_vimrc                        # ~/.vimrc (Raspbian only, via .chezmoiignore)
├── private_dot_config/
│   ├── kitty/                       # ~/.config/kitty/
│   ├── mise/config.toml.tmpl        # ~/.config/mise/config.toml (rendered [tools])
│   ├── nvim/                        # ~/.config/nvim/ (LazyVim: init.lua,
│   │   │                            # lua/config/, lua/plugins/ - all managed)
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

## Troubleshooting

**`mise install` fails with `404` on `https://dl.google.com/go/...`, or uv's
attestation check fails with `TUF repository load failed`.** Both point at the
same cause: on networks whose IPv6 route to Google's CDN is broken, IPv4 works
and every IPv6 request 404s. Prefer IPv4 in `/etc/gai.conf`:

```bash
echo 'precedence ::ffff:0:0/96 100' | sudo tee -a /etc/gai.conf
```

Check before adding it: Ubuntu ships that exact line **commented out**, so a
`grep -q` guard matches the comment and silently does nothing. Anchor on
`^precedence`. Delete the line again if the IPv6 route gets fixed. The CI
container tests apply the same line, for the same reason (containers have their
own `/etc`).

**`command not found` for a mise tool in a non-interactive shell.** Only fish
activates mise (via `config.fish`); plain `bash`/`sh` scripts need
`mise exec -- <cmd>`, or the tool belongs in `global_tools` so `hybrid` mode
symlinks it into `/usr/local/bin`.

**`rust-analyzer` loops or fails with `mise ERROR shim fallback recursion
detected for rust-analyzer`.** This is mise's rust backend plus rustup, not a
broken config here. mise installs Rust through rustup, and rustup ships a
`rust-analyzer` *proxy* in `~/.cargo/bin` whether or not the toolchain has the
component; mise also creates a shim for it. So the proxy reports `rust-analyzer
is unavailable for the active toolchain`, falls back to `PATH`, finds mise's
shim, which asks rustup again: a loop.

The cause is a missing rustup component (`rust-analyzer` is not part of
rustup's `minimal`/`default` profiles). Fix it in the toolchain:

```bash
rustup component add rust-analyzer          # add rust-src too for std source
rust-analyzer --version                      # -> rust-analyzer 1.97.1 (8bab26f)
```

To make it permanent for a mise-managed Rust, declare the components instead of
installing them by hand, so `mise install` re-adds them after a toolchain bump:

```toml
[tools]
rust = { version = "1.97", profile = "minimal", components = ["rust-analyzer", "rust-src", "rustfmt", "clippy"] }
```

That is exactly what `.chezmoidata/software.yaml` now declares for this repo
(`mise.tools.rust`), so a fresh machine gets a working `rust-analyzer` without
the manual step. The same table works in a project-local `mise.toml` when a repo
wants a different toolchain.

Notes: `profile: minimal` keeps `RUSTUP_HOME` at about 750 MB; rustup's `default`
profile adds `rust-docs` and roughly doubles that. Excluding the shim
(`mise settings shims.exclude=rust-analyzer`) only turns the loop into a clean
`Unknown binary 'rust-analyzer'` error; it is not a fix.

## CI

GitHub Actions runs on every push/PR (plus a weekly scheduled run to catch
upstream breakage: new tool versions, URL rot):

- **lint** — shellcheck on plain scripts and on rendered hook templates; renders
  `~/.config/mise/config.toml` and validates it as TOML; asserts that no tool is
  declared in both a distro package list and `mise.tools`; renders the fish
  config for both the Ubuntu and Raspbian branches and parse-checks it with
  `fish -n`; verifies `.chezmoiignore` deploys `.vimrc` only on Raspbian and
  keeps `init.sh`/`update.sh` out of `$HOME`
- **ubuntu-2404 / archlinux** — full end-to-end: the exact `init.sh` a fresh
  machine would run, inside the official `ubuntu:24.04` / `archlinux:base-devel`
  containers as an unprivileged user with sudo, then assertions on the installed
  state: every mise tool at its pinned version, `/usr/local/bin/go` is a real
  symlink (no shim), Neovim/kubectl/kind/helm resolve through shims in a login
  shell, distro packages present, the LazyVim config loads with no startup
  errors, the fish config parses and starts

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
