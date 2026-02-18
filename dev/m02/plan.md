# M2: Core Data Model & Errors — Work Plan

## Overview

Rename module namespace from `Skills::Ref` to `AIgent::Skill`, then implement the exception hierarchy and the SkillProperties model.
Issues: #33, #5, #6, #7.

## Branch Strategy

- **Dev branch**: `dev/m02` (created from `main`)
- **Task branches**: `task/m02-<name>` (created from `dev/m02`)
- After each wave, task branches merge into `dev/m02`
- After all waves, draft PR from `dev/m02` → `main`
- `main` is never touched directly
- PR body uses `Closes #N` in the Summary section to auto-close issues on merge (see CLAUDE.md for full format)

## Waves

### Wave 0 — Rename

Must happen first: all subsequent work uses the new namespace.
Single agent — the rename touches many files and must be atomic.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| R | `task/m02-rename` | #33 | Rename `Skills::Ref` → `AIgent::Skill` everywhere |

**Scope:**

Code:
- `lib/Skills/Ref.rakumod` → `lib/AIgent/Skill.rakumod`
- `lib/Skills/Ref/*.rakumod` → `lib/AIgent/Skill/*.rakumod` (Errors, Models, Parser, Prompt, Validator, Builder)
- Remove empty `lib/Skills/` directory tree
- All `unit module Skills::Ref::*` → `unit module AIgent::Skill::*`
- `META6.json`: name `Skills::Ref` → `AIgent::Skill`, update all provides paths

Docs:
- `CLAUDE.md`: module name, exception classes, module file paths
- `README.md`: title, intro, about stanza
- `dev/plan.md`: project structure, design decisions table, all milestone/issue descriptions
- `.github/ISSUE_TEMPLATE/bug_report.md`: version line label

GitHub issues:
- Update titles and bodies of all open issues that reference `Skills::Ref`

**Merge**: R → `dev/m02`. Checkpoint with user.

### Wave 1 — Implementation

Errors and Models are independent — neither depends on the other.
Both can be implemented in parallel.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| A | `task/m02-errors` | #5 | Implement `lib/AIgent/Skill/Errors.rakumod` |
| B | `task/m02-models` | #6 | Implement `lib/AIgent/Skill/Models.rakumod` |

**Merge**: A, B → `dev/m02`. Checkpoint with user.

#### Agent A — Errors (#5)

Replace the stub `unit module` with exception classes:

```raku
class X::AIgent::Skill is Exception {
    has Str $.message;
}

class X::AIgent::Skill::Parse is X::AIgent::Skill {}

class X::AIgent::Skill::Validation is X::AIgent::Skill {
    has Str @.errors;
    method message(--> Str) {
        @!errors.elems == 1
            ?? @!errors[0]
            !! "Validation failed:\n" ~ @!errors.map({ "  - $_" }).join("\n")
    }
}
```

Key decisions:
- `X::AIgent::Skill` is the base, inheriting from `Exception`
- `has Str $.message` auto-generates the `message` accessor required by `Exception`; no explicit method needed
- `X::AIgent::Skill::Parse` inherits from base (no extra attributes)
- `X::AIgent::Skill::Validation` has `@.errors` (list of error strings) and overrides `message` to format them
- All classes are exported by being declared at package level (no `unit module` wrapper — the file defines classes directly)

#### Agent B — Models (#6)

Replace the stub `unit module` with the `SkillProperties` class:

```raku
class AIgent::Skill::Models::SkillProperties is export {
    has Str $.name        is required;
    has Str $.description is required;
    has Str $.license;
    has Str $.compatibility;
    has Str $.allowed-tools;
    has      %.metadata;

    method to-hash(--> Hash) {
        my %h = :$!name, :$!description;
        %h<license>       = $_ with $!license;
        %h<compatibility> = $_ with $!compatibility;
        %h<allowed-tools> = $_ with $!allowed-tools;
        %h<metadata>      = %!metadata if %!metadata;
        %h;
    }
}
```

Key decisions:
- `name` and `description` are `is required`
- Optional fields (`license`, `compatibility`, `allowed-tools`) are `Str` without `is required` — undefined by default
- `metadata` is `%` (untyped Hash, not `Hash[Str, Str]`) — YAML frontmatter metadata may contain nested structures; untyped `Hash` avoids silent coercion bugs and aligns with how `YAMLish` parses arbitrary YAML values
- `to-hash()` excludes undefined optional fields and empty metadata
- Class is `is export` so it can be imported with `use AIgent::Skill::Models`

### Wave 2 — Tests

Depends on Wave 1 (tests import the modules).

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| C | `task/m02-tests` | #7 | Write `t/01-errors.rakutest` and `t/02-models.rakutest` |

**Merge**: C → `dev/m02`. Checkpoint with user.

#### Agent C — Tests (#7)

**`t/01-errors.rakutest`** (~10 tests):
- `X::AIgent::Skill` can be constructed and thrown
- `X::AIgent::Skill` `.message` returns the message string
- `X::AIgent::Skill::Parse` isa `X::AIgent::Skill`
- `X::AIgent::Skill::Parse` can be caught as `X::AIgent::Skill`
- `X::AIgent::Skill::Validation` isa `X::AIgent::Skill`
- `X::AIgent::Skill::Validation` `.errors` returns the error list
- `X::AIgent::Skill::Validation` `.message` formats single error
- `X::AIgent::Skill::Validation` `.message` formats multiple errors
- Catching with `CATCH` block by type

**`t/02-models.rakutest`** (~12 tests):
- Construction with required fields only
- Construction with all fields
- Construction fails without `name` (required)
- Construction fails without `description` (required)
- `.to-hash` with required fields only — has only `name` and `description`
- `.to-hash` with license — includes `license`
- `.to-hash` with all optional fields — includes all
- `.to-hash` with empty metadata — excludes `metadata`
- `.to-hash` with non-empty metadata — includes `metadata`
- `.name`, `.description` accessors work
- `.allowed-tools` accessor works
- `.metadata` accessor returns hash

### Post-waves

1. Push `dev/m02` to remote
2. Create draft PR `dev/m02` → `main`
3. User reviews and merges when ready

## Verification

After all waves, on `dev/m02`:

```bash
just lint                              # passes
just test                              # all tests pass
raku -Ilib -e 'use AIgent::Skill::Errors; X::AIgent::Skill::Parse.new(:message<test>).throw' 2>&1 | head -1
# → "test"
raku -Ilib -e 'use AIgent::Skill::Models; say AIgent::Skill::Models::SkillProperties.new(:name<foo>, :description<bar>).to-hash'
# → {description => bar, name => foo}
```

## Post-review updates

| Finding | Severity | Resolution |
|---------|----------|------------|
| R1 metadata type mismatch | Medium | Keep untyped `%.metadata` in plan. Updated key decisions to explain rationale (YAML may contain nested values). Updated issue #6 to say `Hash` instead of `Hash[Str, Str]`. |
| R2 auto-close vs PR format | Medium | Clarified in branch strategy: `Closes #N` goes in the PR body Summary section. Updated CLAUDE.md PR format to show placement. |
| R3 redundant `method message` | Low | Removed explicit `method message` from base `X::AIgent::Skill`. `has Str $.message` already provides the accessor. Added key decision note. |
| R4 stale README status | Low | Updated README status line. Added to Wave 0 rename scope (README is already listed there). |
