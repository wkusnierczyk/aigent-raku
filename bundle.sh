#!/usr/bin/env bash
# bundle.sh — Build a self-contained aigent tarball using relocatable Rakudo
#
# Usage:
#   ./bundle.sh                       # auto-detect current platform
#   ./bundle.sh linux-x86_64          # specify target platform
#   ./bundle.sh macos-arm64           # macOS Apple Silicon
#   ./bundle.sh macos-x86_64          # macOS Intel
#
# Output: dist/aigent-<version>-<platform>.tar.gz
#
# This bundles Rakudo + zef + AIgent::Skill into a fully self-contained
# tarball that requires zero external dependencies. Users just extract
# and run the `aigent` wrapper script.

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
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)  os="linux" ;;
        Darwin) os="macos" ;;
        *)      error "Unsupported OS: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="x86_64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)             error "Unsupported architecture: $arch" ;;
    esac

    echo "${os}-${arch}"
}

PLATFORM="${1:-$(detect-platform)}"

# Map platform to Rakudo download parameters
case "$PLATFORM" in
    linux-x86_64)
        RAKUDO_OS="linux"
        RAKUDO_ARCH="x86_64"
        RAKUDO_CC="gcc"
        ;;
    macos-arm64)
        RAKUDO_OS="macos"
        RAKUDO_ARCH="arm64"
        RAKUDO_CC="clang"
        ;;
    macos-x86_64)
        RAKUDO_OS="macos"
        RAKUDO_ARCH="x86_64"
        RAKUDO_CC="clang"
        ;;
    *)
        error "Unknown platform: $PLATFORM (expected: linux-x86_64, macos-arm64, macos-x86_64)"
        ;;
esac

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAKUDO_VERSION="${RAKUDO_VERSION:-2026.01}"
RAKUDO_BUILD="${RAKUDO_BUILD:-01}"
RAKUDO_TARBALL="rakudo-moar-${RAKUDO_VERSION}-${RAKUDO_BUILD}-${RAKUDO_OS}-${RAKUDO_ARCH}-${RAKUDO_CC}.tar.gz"
RAKUDO_URL="https://rakudo.org/dl/rakudo/${RAKUDO_TARBALL}"
RAKUDO_DIR_NAME="rakudo-moar-${RAKUDO_VERSION}-${RAKUDO_BUILD}-${RAKUDO_OS}-${RAKUDO_ARCH}-${RAKUDO_CC}"

# Read version from META6.json
VERSION="$(raku -MJSON::Fast -e 'say from-json(slurp "META6.json")<version>' 2>/dev/null || echo "0.0.0")"
BUNDLE_NAME="aigent-${VERSION}-${PLATFORM}"
WORK_DIR="$(mktemp -d)"
DIST_DIR="${SCRIPT_DIR}/dist"

info "Building bundle: ${BUNDLE_NAME}"
info "Platform: ${PLATFORM}"
info "Rakudo: ${RAKUDO_VERSION}-${RAKUDO_BUILD}"
info "Working directory: ${WORK_DIR}"

# Cleanup on exit
cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Step 1: Download relocatable Rakudo
# ---------------------------------------------------------------------------

CACHE_DIR="${SCRIPT_DIR}/.cache"
mkdir -p "${CACHE_DIR}"

if [[ -f "${CACHE_DIR}/${RAKUDO_TARBALL}" ]]; then
    info "Using cached Rakudo tarball: ${RAKUDO_TARBALL}"
else
    info "Downloading Rakudo: ${RAKUDO_URL}"
    curl -fSL -o "${CACHE_DIR}/${RAKUDO_TARBALL}" "${RAKUDO_URL}"
fi

info "Extracting Rakudo..."
tar -xzf "${CACHE_DIR}/${RAKUDO_TARBALL}" -C "${WORK_DIR}"

RAKUDO="${WORK_DIR}/${RAKUDO_DIR_NAME}"

if [[ ! -x "${RAKUDO}/bin/raku" ]]; then
    error "Rakudo binary not found at ${RAKUDO}/bin/raku"
fi

info "Rakudo extracted: $(bash -c "${RAKUDO}/bin/raku --version" | head -1)"

# ---------------------------------------------------------------------------
# Step 2: Install zef into relocatable Rakudo
# ---------------------------------------------------------------------------

info "Installing zef..."
ZEF_DIR="${WORK_DIR}/zef"
git clone --quiet --depth 1 https://github.com/ugexe/zef.git "${ZEF_DIR}"
bash -c "cd '${ZEF_DIR}' && '${RAKUDO}/bin/raku' -I. bin/zef install . --/test 2>&1" | tail -3

ZEF="${RAKUDO}/share/perl6/site/bin/zef"
if [[ ! -f "${ZEF}" ]]; then
    # Try alternate location
    ZEF="$(find "${RAKUDO}" -name 'zef' -path '*/bin/zef' | head -1)"
fi
[[ -f "${ZEF}" ]] || error "zef installation failed"

info "zef installed"

# ---------------------------------------------------------------------------
# Step 3: Install AIgent::Skill from current source
# ---------------------------------------------------------------------------

info "Installing AIgent::Skill from source..."
# Run zef directly — the shell wrapper resolves its own Rakudo via relative path
"${ZEF}" install "${SCRIPT_DIR}" --/test 2>&1 | tail -5

# The installed aigent is also a shell wrapper with a relative Rakudo path
AIGENT_BIN="${RAKUDO}/share/perl6/site/bin/aigent"
[[ -f "${AIGENT_BIN}" ]] || error "aigent installation failed"

# Verify it works
"${AIGENT_BIN}" --help >/dev/null 2>&1 || error "aigent --help failed"
"${AIGENT_BIN}" --about >/dev/null 2>&1 || error "aigent --about failed"
info "aigent installed and verified"

# ---------------------------------------------------------------------------
# Step 4: Create wrapper script
# ---------------------------------------------------------------------------

info "Creating wrapper script..."
cat > "${RAKUDO}/aigent" << 'WRAPPER'
#!/usr/bin/env bash
# aigent — AI Agent Skill Builder and Validator
# Self-contained wrapper (no external Raku/zef required)

# Resolve symlinks to find the real bundle directory
resolve_path() {
    local target="$1"
    # macOS may lack readlink -f; use a POSIX loop
    while [ -L "$target" ]; do
        local dir="$(cd "$(dirname "$target")" && pwd)"
        target="$(readlink "$target")"
        [[ "$target" != /* ]] && target="$dir/$target"
    done
    echo "$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
}

BUNDLE_DIR="$(dirname "$(resolve_path "${BASH_SOURCE[0]}")")"

exec "${BUNDLE_DIR}/share/perl6/site/bin/aigent" "$@"
WRAPPER
chmod +x "${RAKUDO}/aigent"

# ---------------------------------------------------------------------------
# Step 5: Strip unnecessary files to reduce size
# ---------------------------------------------------------------------------

info "Stripping unnecessary files..."
# Headers and pkg-config — not needed at runtime
rm -rf "${RAKUDO}/include"
rm -rf "${RAKUDO}/share/pkgconfig"

# Debug/profiling binaries — not needed for users
rm -f "${RAKUDO}/bin/perl6"*
rm -f "${RAKUDO}/bin/nqp"*
rm -f "${RAKUDO}/bin/"*debug*
rm -f "${RAKUDO}/bin/"*valgrind*
rm -f "${RAKUDO}/bin/"*gdb*
rm -f "${RAKUDO}/bin/"*lldb*

# zef shell wrappers — no longer needed after installation
rm -f "${RAKUDO}/share/perl6/site/bin/zef"*

# ---------------------------------------------------------------------------
# Step 6: Rename and package
# ---------------------------------------------------------------------------

info "Packaging..."
mv "${RAKUDO}" "${WORK_DIR}/${BUNDLE_NAME}"
mkdir -p "${DIST_DIR}"
tar -czf "${DIST_DIR}/${BUNDLE_NAME}.tar.gz" -C "${WORK_DIR}" "${BUNDLE_NAME}"

TARBALL_SIZE="$(du -sh "${DIST_DIR}/${BUNDLE_NAME}.tar.gz" | cut -f1)"

info "Bundle created: dist/${BUNDLE_NAME}.tar.gz (${TARBALL_SIZE})"
info ""
info "To use:"
info "  tar -xzf ${BUNDLE_NAME}.tar.gz"
info "  ./${BUNDLE_NAME}/aigent --help"
