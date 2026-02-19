#!/usr/bin/env bash
# install.sh — Install aigent (AIgent::Skill)
#
# Usage:
#   curl -fsSL https://github.com/wkusnierczyk/aigent-skills/releases/latest/download/install.sh | bash
#
# What this does:
#   1. Downloads a self-contained aigent bundle for your platform
#   2. Extracts it to ~/.aigent
#   3. Adds ~/.aigent/bin to your PATH
#
# No Raku, zef, or other dependencies required.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${BOLD}${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
warn()  { echo -e "${BOLD}${YELLOW}warning:${RESET} $*"; }
error() { echo -e "${BOLD}${RED}error:${RESET} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Detect platform
# ---------------------------------------------------------------------------

detect-platform() {
    local os arch

    case "$(uname -s)" in
        Linux)  os="linux" ;;
        Darwin) os="macos" ;;
        *)      error "Unsupported OS: $(uname -s). Only Linux and macOS are supported." ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)  arch="x86_64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)             error "Unsupported architecture: $(uname -m)" ;;
    esac

    # No arm64 Linux bundle yet
    if [[ "$os" == "linux" && "$arch" == "arm64" ]]; then
        error "Linux arm64 is not yet supported. See README for alternatives."
    fi

    echo "${os}-${arch}"
}

PLATFORM="$(detect-platform)"
INSTALL_DIR="${AIGENT_HOME:-$HOME/.aigent}"
REPO="wkusnierczyk/aigent-skills"

# ---------------------------------------------------------------------------
# Fetch latest release version
# ---------------------------------------------------------------------------

info "Detecting latest release..."
LATEST_TAG="$(curl -fsSL -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"

if [[ -z "${LATEST_TAG}" ]]; then
    error "Could not determine latest release. Check https://github.com/${REPO}/releases"
fi

VERSION="${LATEST_TAG#v}"
TARBALL="aigent-${VERSION}-${PLATFORM}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${TARBALL}"

info "Installing aigent ${VERSION} for ${PLATFORM}"

# ---------------------------------------------------------------------------
# Download and extract
# ---------------------------------------------------------------------------

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

info "Downloading ${TARBALL}..."
if ! curl -fSL -o "${WORK_DIR}/${TARBALL}" "${DOWNLOAD_URL}"; then
    error "Download failed. No bundle available for ${PLATFORM} at ${LATEST_TAG}."
fi

info "Extracting to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "${WORK_DIR}/${TARBALL}" --strip-components=1 -C "${INSTALL_DIR}"

# Verify
if [[ ! -x "${INSTALL_DIR}/aigent" ]]; then
    error "Installation failed — aigent wrapper not found."
fi

"${INSTALL_DIR}/aigent" --about || error "aigent --about failed after installation"

# ---------------------------------------------------------------------------
# Add to PATH
# ---------------------------------------------------------------------------

BIN_DIR="${INSTALL_DIR}"
SHELL_NAME="$(basename "${SHELL:-/bin/bash}")"
RC_FILE=""

case "$SHELL_NAME" in
    bash) RC_FILE="$HOME/.bashrc" ;;
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    fish) RC_FILE="$HOME/.config/fish/config.fish" ;;
esac

PATH_LINE="export PATH=\"${BIN_DIR}:\$PATH\""
if [[ "$SHELL_NAME" == "fish" ]]; then
    PATH_LINE="set -gx PATH ${BIN_DIR} \$PATH"
fi

if [[ -n "$RC_FILE" ]]; then
    if ! grep -qF "${BIN_DIR}" "$RC_FILE" 2>/dev/null; then
        echo "" >> "$RC_FILE"
        echo "# aigent" >> "$RC_FILE"
        echo "$PATH_LINE" >> "$RC_FILE"
        info "Added ${BIN_DIR} to PATH in ${RC_FILE}"
        info "Run 'source ${RC_FILE}' or open a new terminal to use aigent."
    else
        info "${BIN_DIR} already in ${RC_FILE}"
    fi
else
    warn "Could not detect shell config file."
    warn "Add this to your shell profile:"
    warn "  ${PATH_LINE}"
fi

echo ""
info "Installation complete!"
info "Run 'aigent --help' to get started."
