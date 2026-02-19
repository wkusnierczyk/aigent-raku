# M8: Main Module & Documentation

## Overview

Wire up the public API through `AIgent::Skill` re-exports, finalize README
documentation, add a release workflow, and create a changelog.

- Branch `dev/m08` from `main`
- Issues: #20, #21, #24, #25

## Dependencies

- M7 (Skill Builder) — merged

## Deliverables

### 1. Main module exports (#20)

**File:** `lib/AIgent/Skill.rakumod`

Currently a stub (`unit module AIgent::Skill;`).  Wire up re-exports so
library consumers can `use AIgent::Skill` and get the full public API.

#### Re-export list

From `AIgent::Skill::Errors`:
- `X::AIgent::Skill`
- `X::AIgent::Skill::Parse`
- `X::AIgent::Skill::Build`
- `X::AIgent::Skill::Validation`

From `AIgent::Skill::Models`:
- `SkillProperties`

From `AIgent::Skill::Parser`:
- `find-skill-md`
- `parse-frontmatter`
- `read-properties`

From `AIgent::Skill::Validator`:
- `validate`
- `validate-metadata`

From `AIgent::Skill::Prompt`:
- `to-prompt`

From `AIgent::Skill::Builder`:
- `SkillSpec`
- `BuildResult`
- `derive-name`
- `generate-description`
- `generate-body`
- `check-body-warnings`
- `assess-clarity`
- `build-skill`

#### Implementation

Raku does **not** automatically re-export `is export` symbols from submodules.
A `use Foo::Bar` inside `Foo` imports symbols into `Foo`'s lexical scope, but
consumers of `use Foo` will not see them.

The fix is an explicit `sub EXPORT()` that returns a hash mapping symbol names
to their values.  The `use` statements must appear at file scope (outside
`sub EXPORT`) so the symbols are available to reference in the hash.  This
means `unit module AIgent::Skill;` must be dropped — with `unit module`, a
bare `sub EXPORT` would become a module method instead of the special export
hook.

```raku
use AIgent::Skill::Errors;
use AIgent::Skill::Models;
use AIgent::Skill::Parser;
use AIgent::Skill::Validator;
use AIgent::Skill::Prompt;
use AIgent::Skill::Builder;

sub EXPORT() {
    %(
        # Exceptions
        'X::AIgent::Skill'            => X::AIgent::Skill,
        'X::AIgent::Skill::Parse'     => X::AIgent::Skill::Parse,
        'X::AIgent::Skill::Build'     => X::AIgent::Skill::Build,
        'X::AIgent::Skill::Validation' => X::AIgent::Skill::Validation,

        # Data model
        'SkillProperties' => SkillProperties,
        'SkillSpec'       => SkillSpec,
        'BuildResult'     => BuildResult,

        # Parser
        '&find-skill-md'      => &find-skill-md,
        '&parse-frontmatter'  => &parse-frontmatter,
        '&read-properties'    => &read-properties,

        # Validator
        '&validate'          => &validate,
        '&validate-metadata' => &validate-metadata,

        # Prompt
        '&to-prompt' => &to-prompt,

        # Builder
        '&derive-name'           => &derive-name,
        '&generate-description'  => &generate-description,
        '&generate-body'         => &generate-body,
        '&check-body-warnings'   => &check-body-warnings,
        '&assess-clarity'        => &assess-clarity,
        '&build-skill'           => &build-skill,
    )
}
```

Key convention: sub names are prefixed with `&` (sigiled), class/exception
names are bare (unsigiled).

#### Verification

```bash
raku -Ilib -e 'use AIgent::Skill; say SkillProperties.new(:name("x"), :description("y")).name'
raku -Ilib -e 'use AIgent::Skill; say find-skill-md("extracting-data".IO)'
raku -Ilib -e 'use AIgent::Skill; say X::AIgent::Skill::Parse.new(:message("test")).message'
```

#### Test

`t/08-main.rakutest` — verify that all symbols are accessible via
`use AIgent::Skill`:

1. Exception classes importable and throwable (4 assertions)
2. `SkillProperties` constructable (1)
3. `SkillSpec` and `BuildResult` constructable (2)
4. `find-skill-md` callable (1)
5. `parse-frontmatter` callable (1)
6. `read-properties` callable (1)
7. `validate` callable (1)
8. `validate-metadata` callable (1)
9. `to-prompt` callable (1)
10. `build-skill` callable (1)
11. `derive-name` callable (1)
12. `assess-clarity` callable (1)

Total: ~16 assertions.  These are import-smoke tests, not functionality tests
(those are covered in t/01–07).

### 2. Update README.md (#21)

Restructure the README for end-users, not just developers.  The current
README is developer-focused (setup, git hooks, CI).

#### New structure

```
# aigent: AI Agent Skill Builder and Validator
## Status
## Installation
  - zef install
  - From source
## Usage
  ### Library API
    - use AIgent::Skill
    - Validate a skill
    - Parse skill properties
    - Generate prompts
    - Build a new skill
  ### CLI
    - validate
    - read-properties
    - to-prompt
    - build
    - init
    - --about / --help
## SKILL.md Format
  - Frontmatter fields
  - Body sections
## API Reference
  - Classes (SkillProperties, SkillSpec, BuildResult)
  - Functions (by module)
  - Exceptions
## Development
  ### Prerequisites
  ### Setup
  ### Common Tasks
  ### Versioning
  ### Git Hooks
## CI/CD Workflows
## Development Plan
## References
## About and License
```

Key additions:
- Installation section (was missing entirely)
- Usage section with runnable examples
- SKILL.md format documentation
- API reference table
- CLI docs with all subcommands including `build` and `init`

Key changes:
- Status updated to "M8 complete"
- CI section updated to reflect current Ubuntu+macOS matrix (Windows removed
  due to upstream REA MAX_PATH issue — Raku/REA#7)
- Move development details below usage (users first, developers second)

### 3. Release workflow (#24)

**File:** `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: Raku/setup-raku@v1
        with:
          raku-version: 'latest'

      - name: Install dependencies
        run: zef install --deps-only . --/test

      - name: Install prove6
        run: zef install App::Prove6 --/test

      - name: Run tests
        run: prove6 -Ilib -l t/

      - name: Extract changelog
        id: changelog
        run: |
          VERSION=${GITHUB_REF_NAME#v}
          awk "/^## $VERSION/{flag=1; next} /^## /{flag=0} flag" CHANGES.md > release_notes.md
          if [ ! -s release_notes.md ]; then
            echo "::error::No changelog entry found for version $VERSION in CHANGES.md"
            exit 1
          fi
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          body_path: release_notes.md
          generate_release_notes: false
```

Notes:
- Runs full test suite before releasing
- Extracts per-version notes from CHANGES.md
- Guard: fails the workflow if release notes are empty (heading mismatch)
- No ecosystem publishing for now — deferred until the module is stable enough
  for public consumption.  The full plan (#24) mentions zef publishing; this
  will be added as a follow-up when ready.
- Tag convention: `v0.1.0` (semver with `v` prefix)

### 4. CHANGES.md (#25)

**File:** `CHANGES.md`

Initial content covering v0.1.0 (all milestones M1–M8):

```markdown
# Changes

## 0.1.0

Initial release.

### Features
- SKILL.md parser with YAML frontmatter extraction
- Metadata validator with Anthropic spec compliance
  (reserved words, XML tag rejection, field constraints)
- XML prompt generator for multi-skill system prompts
- Skill builder with dual-mode architecture
  (LLM-enhanced + deterministic fallback)
- CLI tool (`aigent`) with subcommands:
  validate, read-properties, to-prompt, build, init
- Main module (`AIgent::Skill`) re-exporting full public API

### Infrastructure
- CI on Ubuntu and macOS
- Automatic retry of failed CI jobs with exponential backoff
- GitHub project board automation
- Release workflow with changelog extraction
```

### 5. Version bump

Bump version from `0.0.1` to `0.1.0` in META6.json to mark the first
feature-complete release.

```bash
just version-set 0.1.0
```

## Implementation order

1. Main module exports (`lib/AIgent/Skill.rakumod`) + test
2. CHANGES.md
3. Release workflow
4. README update (largest task, benefits from everything else being done)
5. Version bump (last, so all changes are in place)
6. Update README status to "M8 complete"

## Test plan

Automated:
- `t/08-main.rakutest` — ~16 assertions for re-export smoke tests
- `just check` — all ~152 tests pass (136 existing + ~16 new)

Manual:
```bash
# Verify single-import works
raku -Ilib -e 'use AIgent::Skill; say validate("extracting-data".IO).raku'

# Verify CLI still works after refactoring
d=$(mktemp -d)
raku -Ilib bin/aigent build "Process PDF files" --dir "$d" --no-llm
raku -Ilib bin/aigent validate "$d"/processing-pdf-files
raku -Ilib bin/aigent read-properties "$d"/processing-pdf-files
rm -rf "$d"

# Verify release workflow syntax
gh workflow view release.yml 2>/dev/null || echo "upload first"
```

## Smoke test

```bash
# Full pipeline through main module
raku -Ilib -e '
  use AIgent::Skill;
  my $spec = SkillSpec.new(:purpose("Analyze CSV files"));
  my $dir = "/tmp/aigent-m08-smoke".IO;
  $dir.mkdir unless $dir.e;
  my $result = build-skill($spec, $dir);
  say "Built: {$result.output-dir}";
  say "Name: {$result.properties.name}";
  my @errors = validate($result.output-dir);
  say "Validation: {@errors ?? @errors.join(", ") !! "PASS"}";
  my @dirs = ($result.output-dir,);
  my IO::Path @typed = @dirs;
  say "Prompt length: {to-prompt(@typed).chars} chars";
'
```
