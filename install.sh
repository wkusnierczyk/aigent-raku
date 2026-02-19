#!/usr/bin/env bash
# install.sh — Install aigent (AIgent::Skill) on macOS or Linux
#
# Usage:
#   curl -fsSL https://github.com/wkusnierczyk/aigent-skills/releases/latest/download/install.sh | bash
#
# What this does:
#   1. Checks for Rakudo (Raku compiler) — installs via rakubrew if missing
#   2. Checks for zef (Raku module manager) — comes with rakubrew
#   3. Installs AIgent::Skill from the Raku ecosystem
#
# After installation, `aigent` will be on your PATH.

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
# Pre-flight checks
# ---------------------------------------------------------------------------

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    error "Windows is not supported by this installer. See README for alternatives."
fi

# ---------------------------------------------------------------------------
# Step 1: Ensure Rakudo is available
# ---------------------------------------------------------------------------

if command -v raku &>/dev/null; then
    info "Rakudo found: $(raku --version | head -1)"
else
    info "Rakudo not found. Installing via rakubrew..."

    if command -v rakubrew &>/dev/null; then
        info "rakubrew found, building latest Rakudo..."
    else
        info "Installing rakubrew..."
        curl -fsSL https://rakubrew.org/install-on-perl.sh | bash

        # Source rakubrew into current session
        export PATH="$HOME/.rakubrew/bin:$PATH"
        eval "$(rakubrew init Bash)"
    fi

    rakubrew build moar
    rakubrew switch moar

    if ! command -v raku &>/dev/null; then
        error "Rakudo installation failed. Please install manually: https://rakudo.org/downloads"
    fi

    info "Rakudo installed: $(raku --version | head -1)"
fi

# ---------------------------------------------------------------------------
# Step 2: Ensure zef is available
# ---------------------------------------------------------------------------

if command -v zef &>/dev/null; then
    info "zef found: $(zef --version 2>/dev/null || echo 'unknown version')"
else
    info "zef not found. Installing..."

    if command -v rakubrew &>/dev/null; then
        rakubrew build-zef
    else
        # Manual zef install
        git clone https://github.com/ugexe/zef.git /tmp/zef-install
        raku -I/tmp/zef-install/lib /tmp/zef-install/bin/zef install .
        rm -rf /tmp/zef-install
    fi

    if ! command -v zef &>/dev/null; then
        error "zef installation failed. Please install manually: https://github.com/ugexe/zef"
    fi
fi

# ---------------------------------------------------------------------------
# Step 3: Install AIgent::Skill
# ---------------------------------------------------------------------------

info "Installing AIgent::Skill..."

zef install AIgent::Skill

if command -v aigent &>/dev/null; then
    info "Installation complete!"
    echo ""
    aigent --about
    echo ""
    info "Run 'aigent --help' to get started."
else
    warn "AIgent::Skill installed but 'aigent' not found on PATH."
    warn "You may need to add zef's bin directory to your PATH."
    warn "Try: export PATH=\"\$HOME/.rakubrew/bin:\$PATH\""
fi
