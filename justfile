set shell := ["bash", "-euo", "pipefail", "-c"]

# ─── Setup & Install ──────────────────────────────────────────────────

# Install deps, lefthook, and activate git hooks
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Raku dependencies..."
    zef install --deps-only . --/test
    if ! command -v lefthook &>/dev/null; then
        echo "Installing lefthook..."
        if [[ "$(uname)" == "Darwin" ]]; then
            brew install lefthook
        else
            echo "Please install lefthook: https://github.com/evilmartians/lefthook#install"
            exit 1
        fi
    fi
    echo "Activating git hooks..."
    lefthook install
    echo "Done."

# Install module locally via zef
install:
    zef install . --/test

# ─── Testing ──────────────────────────────────────────────────────────

# Run the test suite
test:
    prove6 -Ilib -l t/

# ─── Linting ──────────────────────────────────────────────────────────

# Run all lint checks (syntax + meta)
lint: lint-syntax lint-meta

# Compile-check all source files with raku -c
lint-syntax:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r f; do
        printf "  \033[36m.\033[0m %s\n" "$f"
        raku -Ilib -c "$f"
    done < <(raku -MJSON::Fast -e '.say for from-json(slurp "META6.json")<provides>.values')
    printf "  \033[36m.\033[0m %s\n" "bin/aigent"
    raku -Ilib -c bin/aigent
    echo "All files passed syntax check."

# Validate META6.json required fields
lint-meta:
    @echo "Checking META6.json..."
    raku -MJSON::Fast -e 'my $m = from-json(slurp "META6.json"); die "Missing $_" unless $m{$_} for <name version provides>;'
    @echo "META6.json OK."

# ─── Formatting ───────────────────────────────────────────────────────

# Warn about tabs and trailing whitespace in source files
format:
    #!/usr/bin/env bash
    set -euo pipefail
    ok=true
    check_file() {
        local f="$1"
        if grep -n $'\t' "$f"; then
            echo "  WARNING: tab found in $f"
            ok=false
        fi
        if grep -En '[[:space:]]+$' "$f"; then
            echo "  WARNING: trailing whitespace in $f"
            ok=false
        fi
    }
    while IFS= read -r f; do check_file "$f"; done < <(raku -MJSON::Fast -e '.say for from-json(slurp "META6.json")<provides>.values')
    check_file bin/aigent
    if $ok; then
        echo "No whitespace issues found."
    else
        echo "Whitespace issues detected. Run 'just format-fix' to remove trailing whitespace."
        exit 1
    fi

# Remove trailing whitespace from all source and test files
format-fix:
    #!/usr/bin/env bash
    set -euo pipefail
    fix_file() {
        if [ -f "$1" ]; then
            raku -e 'my $p = @*ARGS[0].IO; $p.spurt: $p.lines.map(*.trim-trailing).join("\n") ~ "\n"' "$1"
            echo "  fixed $1"
        fi
    }
    while IFS= read -r f; do fix_file "$f"; done < <(raku -MJSON::Fast -e '.say for from-json(slurp "META6.json")<provides>.values')
    fix_file bin/aigent
    if [[ -d t ]]; then
        while IFS= read -r f; do fix_file "$f"; done < <(raku -e '.say for "t".IO.dir.grep(*.extension eq any("rakumod","rakutest"))')
    fi
    echo "Trailing whitespace removed."

# ─── Versioning ───────────────────────────────────────────────────────

# Print current version from META6.json
version:
    @raku -MJSON::Fast -e 'say from-json(slurp "META6.json")<version>'

# Set version in META6.json
version-set NEW_VERSION:
    raku -MJSON::Fast -e ' \
        my $path = "META6.json"; \
        my $m = from-json(slurp $path); \
        $m<version> = "{{ NEW_VERSION }}"; \
        spurt $path, to-json($m, :sorted-keys) ~ "\n"; \
    '
    @echo "Version set to {{ NEW_VERSION }}"

# Increment patch version (0.0.1 → 0.0.2)
bump-patch:
    #!/usr/bin/env bash
    set -euo pipefail
    v=$(just version)
    IFS='.' read -r major minor patch <<< "$v"
    patch=$((patch + 1))
    just version-set "$major.$minor.$patch"

# Increment minor version (0.0.1 → 0.1.0)
bump-minor:
    #!/usr/bin/env bash
    set -euo pipefail
    v=$(just version)
    IFS='.' read -r major minor patch <<< "$v"
    minor=$((minor + 1))
    just version-set "$major.$minor.0"

# Increment major version (0.0.1 → 1.0.0)
bump-major:
    #!/usr/bin/env bash
    set -euo pipefail
    v=$(just version)
    IFS='.' read -r major minor patch <<< "$v"
    major=$((major + 1))
    just version-set "$major.0.0"

# ─── Composite ────────────────────────────────────────────────────────

# Full pre-push check: format + lint + test
check: format lint test
