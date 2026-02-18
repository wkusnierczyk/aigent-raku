# M1: Project Scaffolding — Work Plan

## Overview

Set up the Raku module structure, metadata, and dev tooling.
Issues: #1, #2, #3, #4, #23, #27, #28, #29.

## Branch Strategy

- **Dev branch**: `dev/m01` (created from `main`)
- **Task branches**: `task/m01-<name>` (created from `dev/m01`)
- After each wave, task branches merge into `dev/m01`
- After all waves, draft PR from `dev/m01` → `main`
- `main` is never touched directly

## Waves

### Wave 1 — Foundation

Establishes the minimum viable module: metadata, file structure, gitignore.
No interdependencies — all three tasks can run in parallel.

| Agent | Branch | Issue(s) | Task |
|-------|--------|----------|------|
| A | `task/m01-meta` | #1 | Create `META6.json` with name, version (`0.0.1`), auth, description, source-url, deps (YAMLish, JSON::Fast, Test::Async), provides map, bin entry (`aigent`) |
| B | `task/m01-stubs` | #4 | Create stub module files: `lib/Skills/Ref.rakumod`, `lib/Skills/Ref/{Errors,Models,Parser,Prompt,Validator,Builder}.rakumod`, `bin/aigent` |
| C | `task/m01-gitignore` | #3 | Update `.gitignore`: add `.precomp/`, `lib/.precomp/`, and Raku artifacts |

**Merge**: A, B, C → `dev/m01`. Checkpoint with user.

### Wave 2 — Dev Tooling

Depends on Wave 1 (justfile needs META6.json; CLAUDE.md references just targets; lefthook needs source files to lint).

| Agent | Branch | Issue(s) | Task |
|-------|--------|----------|------|
| D | `task/m01-justfile` | #27 | Create `justfile` with targets: `setup`, `install`, `test`, `lint` (= `lint-syntax` + `lint-meta`), `lint-syntax`, `lint-meta`, `format`, `format-fix`, `version`, `version-set`, `bump-patch`, `bump-minor`, `bump-major` |
| E | `task/m01-lefthook` | #28 | Create `lefthook.yml`: pre-commit runs `just lint-syntax` on changed files; pre-push runs `just test` + `just lint` |
| F | `task/m01-claude-md` | #2 | Create `CLAUDE.md` with dev workflow: setup, test, lint, format, version commands |

**Merge**: D, E, F → `dev/m01`. Checkpoint with user.

### Wave 3 — CI/CD

Depends on Wave 2 (CI workflow uses `just` targets for lint).

| Agent | Branch | Issue(s) | Task |
|-------|--------|----------|------|
| G | `task/m01-ci` | #23, #29 | Create `.github/workflows/ci.yml`: trigger on push to main and PRs, setup Raku, cache deps, install deps, run `just lint`, run `just test`. Combines #23 and #29 since lint is part of the CI pipeline. |

**Merge**: G → `dev/m01`. Checkpoint with user.

### Post-waves

1. Push `dev/m01` to remote
2. Create draft PR `dev/m01` → `main`
3. User reviews and merges when ready

## Post-Review Updates

### Review 1 & 2

| # | Finding | Severity | Action |
|---|---------|----------|--------|
| R1.1 | `just setup` not portable — installs lefthook via `brew` only, fails on Linux | Medium | **Fix now**: detect platform, use `brew` on macOS, suggest manual install otherwise |
| R1.2 | `format-fix` uses `sed -i ''` (BSD) — breaks on GNU sed (Linux) | Medium | **Fix now**: use Raku one-liner instead of sed for portability |
| R1.3 | pre-commit glob `**/*.{rakumod,raku}` misses `t/*.rakutest` and `bin/aigent` | Low | **Fix now**: expand glob to include `.rakutest` and `bin/aigent` |
| R2.1 | pre-commit runs `raku -c {staged_files}` — `raku -c` accepts one file only | Medium | **Fix now**: iterate per file with a `for` loop |
| R2.2 | `bin/aigent` has `use lib 'lib'` hardcoded | Low | **Defer**: expected for stub phase, will be replaced by `use AIgent::Skill` when module is implemented |

## Verification

After all waves, on `dev/m01`:

```bash
raku -c lib/Skills/Ref.rakumod                 # compiles
raku -c lib/Skills/Ref/Errors.rakumod          # compiles
raku -c bin/aigent                             # compiles
just lint                                      # passes
just test                                      # passes (no tests yet, but exits 0)
```
