#!/bin/bash
# Installs/updates the latest stable Go toolchain.
# Runs via chezmoi on EVERY apply (run_on_change), but exits fast when the
# installed version already matches upstream latest.
#
# - Arch Linux: pacman (AUR helper fallback), tracks the rolling release.
# - Ubuntu (incl. 24.04): official tarball into /usr/local/go, since apt lags
#   upstream. Checksum is verified against go.dev's published metadata.
set -euo pipefail

GOLANG_BASE_URL="https://go.dev/dl"

log()  { echo "==> [go] $*"; }
info() { echo "    $*"; }
die()  { echo "ERROR: [go] $*" >&2; exit 1; }

# Raspbian: not supported here (heavyweight tarball; the Pi gets no Go toolchain)
os_id=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    os_id="${ID:-}"
fi
case "$os_id" in
    *raspbian*) log "Raspbian: Go toolchain skipped"; exit 0 ;;
esac

# curl wrappers with an IPv4 fallback: on some dual-stack networks the IPv6
# route to dl.google.com misbehaves (404s) while IPv4 works.
curl_meta() { curl -fsSL --max-time 30 "$@" || curl -4fsSL --max-time 30 "$@"; }
curl_dl()   { curl -fsSL --max-time 600 --retry 3 "$@" || curl -4fsSL --max-time 600 --retry 3 "$@"; }

# -----------------------------------------------------------------------------
# Distro detection (Ubuntu or Arch, including common derivatives)
# -----------------------------------------------------------------------------
detect_distro() {
    IS_UBUNTU=false
    IS_ARCH=false

    if [ ! -r /etc/os-release ]; then
        die "cannot detect OS: /etc/os-release missing or unreadable"
    fi
    # shellcheck source=/etc/os-release
    . /etc/os-release

    case "${ID:-}" in
        ubuntu) IS_UBUNTU=true ;;
        arch)   IS_ARCH=true ;;
        *)
            # Treat derivatives as their parent distro.
            case "${ID_LIKE:-}" in
                *debian*|*ubuntu*) IS_UBUNTU=true ;;
                *arch*)            IS_ARCH=true ;;
                *) die "unsupported distro '${ID:-unknown}' (supported: ubuntu, arch)" ;;
            esac
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Upstream version + checksum lookup (go.dev JSON release feed)
# -----------------------------------------------------------------------------
get_latest_version() {
    # First entry of ?mode=json is the latest stable release; "version" is
    # "goX.Y.Z". curl -f fails on HTTP errors; the feed is small.
    curl_meta "${GOLANG_BASE_URL}/?mode=json" \
        | grep -oE '"version": *"go[0-9]+(\.[0-9]+)*"' \
        | head -n1 \
        | grep -oE 'go[0-9]+(\.[0-9]+)*' \
        | sed 's/^go//'
}

get_expected_sha256() {
    # $1: tarball filename, e.g. go1.27.3.linux-amd64.tar.gz
    # The JSON entry for each file looks like:
    #   "filename": "go1.27.3.linux-amd64.tar.gz",
    #   ...
    #   "sha256": "<64 hex chars>",
    # grep -A6 spans that block; the only 64-hex string in it is the digest.
    local tgz="$1"
    curl_meta "${GOLANG_BASE_URL}/?mode=json" \
        | grep -A6 "\"${tgz}\"" \
        | grep -oE '[a-f0-9]{64}' \
        | head -n1
}

# -----------------------------------------------------------------------------
# Ubuntu: official tarball -> /usr/local/go
# -----------------------------------------------------------------------------
install_go_tarball() {
    local latest="$1"

    # Map machine arch to Go tarball arch.
    local goarch
    case "$(uname -m)" in
        x86_64)  goarch="amd64" ;;
        aarch64) goarch="arm64" ;;
        *) die "unsupported machine architecture: $(uname -m)" ;;
    esac

    local tgz="go${latest}.linux-${goarch}.tar.gz"
    local url="${GOLANG_BASE_URL}/${tgz}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    # shellcheck disable=SC2064  # tmp_dir is fixed for the script lifetime
    trap "rm -rf '${tmp_dir}'" EXIT

    info "Downloading ${url}"
    curl_dl -o "${tmp_dir}/${tgz}" "$url" \
        || die "download failed: ${url}"

    local expected actual
    expected="$(get_expected_sha256 "${tgz}")"
    [ -n "$expected" ] || die "could not look up sha256 for ${tgz}"
    actual="$(sha256sum "${tmp_dir}/${tgz}" | awk '{print $1}')"
    if [ "$actual" != "$expected" ]; then
        die "checksum mismatch for ${tgz}: expected ${expected}, got ${actual}"
    fi
    info "Checksum OK (${expected})"

    # Remove any previous tree so upgrades never mix old and new files.
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "${tmp_dir}/${tgz}"

    # Best-effort PATH hook for POSIX shells; fish adds /usr/local/go/bin
    # separately via config.fish.
    if [ -f "$HOME/.profile" ] && ! grep -qs '/usr/local/go/bin' "$HOME/.profile"; then
        printf '\nexport PATH=$PATH:/usr/local/go/bin\n' >> "$HOME/.profile"
        info "Added /usr/local/go/bin to ~/.profile"
    fi
}

install_go_ubuntu() {
    local latest
    latest="$(get_latest_version)" || die "cannot determine latest Go version"
    [ -n "$latest" ] || die "could not determine latest Go version (network issue?)"

    # Detect the currently installed version regardless of PATH: the toolchain
    # we manage lives at /usr/local/go, which may not be on PATH (e.g. non-login
    # shells, or when an older distro go shadows it).
    local current=""
    if [ -x /usr/local/go/bin/go ]; then
        current="$(/usr/local/go/bin/go env GOVERSION 2>/dev/null | sed 's/^go//')"
    elif command -v go >/dev/null 2>&1; then
        current="$(go env GOVERSION 2>/dev/null | sed 's/^go//')"
    fi

    if [ "$current" = "$latest" ]; then
        info "Go ${latest} already installed and up to date"
        return 0
    fi

    if [ -n "$current" ]; then
        log "Upgrading Go ${current} -> ${latest}"
    else
        log "Installing Go ${latest} (tarball -> /usr/local/go)"
    fi
    install_go_tarball "$latest"
    /usr/local/go/bin/go version

    # Warn if some other go (e.g. an old apt package) still shadows ours.
    if command -v go >/dev/null 2>&1 \
        && [ "$(command -v go)" != "/usr/local/go/bin/go" ]; then
        info "Note: '$(command -v go)' comes earlier in PATH than /usr/local/go/bin/go"
        info "      ('go' may resolve to an older toolchain until PATH is adjusted)"
    fi
}

# -----------------------------------------------------------------------------
# Arch: pacman, AUR helper as fallback
# -----------------------------------------------------------------------------
install_go_arch() {
    local latest
    latest="$(get_latest_version)" || die "cannot determine latest Go version"
    [ -n "$latest" ] || die "could not determine latest Go version (network issue?)"

    # On Arch the pacman package owns /usr/bin/go, so PATH detection is right.
    local current=""
    if command -v go >/dev/null 2>&1; then
        current="$(go env GOVERSION 2>/dev/null | sed 's/^go//')"
    fi

    if [ "$current" = "$latest" ]; then
        info "Go ${latest} already installed and up to date"
        return 0
    fi

    log "Installing/updating go package (upstream: ${latest})"
    if sudo pacman -S --noconfirm --needed go; then
        if command -v go >/dev/null 2>&1; then
            info "Installed: $(go version)"
        else
            info "Installed: go (run 'pacman -Qi go' for version)"
        fi
        if [ -n "$current" ]; then
            info "Note: Arch rolls go forward with the distro; minor drift from upstream ${latest} is normal."
        fi
        return 0
    fi

    # Fallback for the rare case the repo copy is broken or missing.
    log "pacman install failed, trying an AUR helper (yay/paru)"
    local helper
    for helper in yay paru; do
        if command -v "$helper" >/dev/null 2>&1; then
            "$helper" -S --noconfirm --needed go
            return 0
        fi
    done
    die "pacman failed and no AUR helper (yay/paru) is available"
}

# -----------------------------------------------------------------------------
main() {
    detect_distro

    if $IS_UBUNTU; then
        install_go_ubuntu
    elif $IS_ARCH; then
        install_go_arch
    else
        die "distro detection failed"
    fi
}

main "$@"
