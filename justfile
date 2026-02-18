set shell := ["bash", "-euo", "pipefail", "-c"]

# Source file globs
lib_files := `find lib -name '*.rakumod'`
src_files := lib_files + " bin/aigent"
all_files := src_files + " " + `find t -name '*.rakumod' -o -name '*.rakutest' 2>/dev/null || true`

# ─── Setup & Install ──────────────────────────────────────────────────

# Install deps, lefthook, and activate git hooks
setup:
    @echo "Installing Raku dependencies..."
    zef install --deps-only . --/test
    @echo "Installing lefthook..."
    brew install lefthook 2>/dev/null || echo "lefthook already installed"
    @echo "Activating git hooks..."
    lefthook install
    @echo "Done."

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
    files=({{ src_files }})
    for f in "${files[@]}"; do
        printf "  \033[36m.\033[0m %s\n" "$f"
        raku -Ilib -c "$f"
    done
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
    files=({{ src_files }})
    ok=true
    for f in "${files[@]}"; do
        if grep -n $'\t' "$f"; then
            echo "  WARNING: tab found in $f"
            ok=false
        fi
        if grep -En '[[:space:]]+$' "$f"; then
            echo "  WARNING: trailing whitespace in $f"
            ok=false
        fi
    done
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
    files=({{ all_files }})
    for f in "${files[@]}"; do
        if [ -f "$f" ]; then
            sed -i '' 's/[[:space:]]*$//' "$f"
            echo "  fixed $f"
        fi
    done
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
