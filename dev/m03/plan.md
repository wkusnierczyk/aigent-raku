# M3: Parser — Work Plan

## Overview

Write tests for the SKILL.md parser, then implement: locate the file, extract YAML frontmatter, and build a `SkillProperties` object.
Issues: #8, #9.

## Branch Strategy

- **Dev branch**: `dev/m03` (created from `main`)
- **Task branches**: `task/m03-<name>` (created from `dev/m03`)
- After each wave, task branches merge into `dev/m03`
- After all waves, draft PR from `dev/m03` → `main`
- `main` is never touched directly
- PR body uses `Closes #N` in the Summary section to auto-close issues on merge (see CLAUDE.md for full format)

## Dependencies

- `AIgent::Skill::Errors` — `X::AIgent::Skill::Parse` and `X::AIgent::Skill::Validation` (from M2)
- `AIgent::Skill::Models` — `SkillProperties` (from M2)
- `YAMLish` — YAML parsing

## Waves

### Wave 1 — Tests

Tests first — they define the contract the parser must satisfy.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| A | `task/m03-tests` | #9 | Write `t/03-parser.rakutest` |

**Merge**: A → `dev/m03`. Checkpoint with user.

#### Agent A — Tests (#9)

**`t/03-parser.rakutest`** (~16 tests):

##### `find-skill-md` tests:
- Returns `SKILL.md` path when uppercase file exists
- Returns `skill.md` path when only lowercase file exists
- Prefers uppercase when both exist
- Returns `Nil` when neither exists

##### `parse-frontmatter` tests:
- Parses valid frontmatter with body → returns `(%metadata, $body)`
- Parses valid frontmatter with empty body → returns `(%metadata, '')`
- Throws `X::AIgent::Skill::Parse` when content does not start with `---`
- Throws `X::AIgent::Skill::Parse` when closing `---` is missing
- Throws `X::AIgent::Skill::Parse` when YAML is invalid
- Throws `X::AIgent::Skill::Parse` when frontmatter is not a mapping (e.g. a YAML list)

##### `read-properties` tests:
- Returns `SkillProperties` for a valid skill directory
- Correctly parses flat metadata into `.metadata` hash
- Correctly preserves nested metadata values (hashes/arrays) as-is
- Correctly parses `allowed-tools` field
- Throws `X::AIgent::Skill::Parse` when SKILL.md is missing
- Throws `X::AIgent::Skill::Validation` when `name` is missing
- Throws `X::AIgent::Skill::Validation` when `description` is missing

Test infrastructure:
- Use `$*TMPDIR.add('aigent-test-' ~ $*PID)` for temp directories
- Create/remove temp dirs in test setup/teardown
- Write `SKILL.md` / `skill.md` files programmatically for each test case

### Wave 2 — Implementation

Make the tests pass.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| B | `task/m03-parser` | #8 | Implement `lib/AIgent/Skill/Parser.rakumod` |

**Merge**: B → `dev/m03`. Checkpoint with user.

#### Agent B — Parser (#8)

Replace the stub `unit module` with three exported subs:

```raku
sub find-skill-md(IO::Path $dir) is export
sub parse-frontmatter(Str $content --> List) is export
sub read-properties(IO::Path $dir --> SkillProperties) is export
```

##### `find-skill-md(IO::Path $dir)`

Locate the skill definition file in a directory.

- Check for `SKILL.md` first (uppercase preferred)
- Fall back to `skill.md` (lowercase)
- Return `IO::Path` if found, `Nil` if neither exists
- No return type constraint — `Nil` is a valid return value and a typed `(--> IO::Path)` would produce a runtime type-check failure
- No exceptions — callers decide how to handle absence

##### `parse-frontmatter(Str $content --> List)`

Extract YAML frontmatter and markdown body from raw file content.

- Content must start with a line containing only `---` (the opening delimiter)
- Find the closing delimiter: a subsequent line containing only `---`
- Parse the YAML between delimiters using `YAMLish`
- Return a two-element list: `(%metadata, $body)`
  - `%metadata` is the parsed YAML hash
  - `$body` is everything after the closing `---`, with leading newline stripped
- Throw `X::AIgent::Skill::Parse` if:
  - Content does not start with `---`
  - No closing `---` delimiter found
  - YAML parsing fails (invalid syntax)
  - Parsed YAML is not a hash/mapping (e.g. a list or scalar)

##### `read-properties(IO::Path $dir --> SkillProperties)`

Full pipeline: find → read → parse → validate required fields → construct.

1. Call `find-skill-md($dir)` — throw `X::AIgent::Skill::Parse` if `Nil`
2. Read the file contents (`.slurp`)
3. Call `parse-frontmatter($content)` to get `(%metadata, $body)`
4. Validate required fields:
   - `name` must exist and be a non-empty string (after trimming)
   - `description` must exist and be a non-empty string (after trimming)
   - Throw `X::AIgent::Skill::Validation` if either is missing or empty
5. Construct and return `SkillProperties` from the metadata hash
   - Map known keys: `name`, `description`, `license`, `compatibility`, `allowed-tools`
   - Remaining keys go into `metadata`

Key decisions:
- This is a *parser*, not a *validator* — it only checks the minimum required for construction (name and description exist). Full validation (name format, length limits, etc.) is M4's job.
- `metadata` values may be nested structures (hashes, arrays); they are stored as-is in the untyped `%.metadata` hash, matching the M2 design decision.
- `allowed-tools` is stored as a plain string; parsing tool specifications (e.g. `Bash(jq:*)`) is the caller's responsibility.
- Empty body after closing `---` is valid — matches Python reference behavior.
- IO failures (e.g. unreadable file) are not caught — Raku's `.slurp` throws `X::IO` naturally, and callers can handle it. The parser only guards against *missing* files (via `find-skill-md`), not permission/corruption errors.

### Post-waves

1. Push `dev/m03` to remote
2. Create draft PR `dev/m03` → `main`
3. User reviews and merges when ready

## Verification

After all waves, on `dev/m03`:

```bash
just lint                              # passes
just test                              # all tests pass (01-errors: 11, 02-models: 13, 03-parser: ~16)
raku -Ilib -e '
    use AIgent::Skill::Parser;
    my $dir = "/path/to/skill".IO;
    my $sp = read-properties($dir);
    say $sp.name;
'
```

## Post-review updates

| Finding | Severity | Resolution |
|---------|----------|------------|
| R1 find-skill-md return type vs Nil | Medium | Dropped `--> IO::Path` return constraint. Added note explaining why. |
| R2 missing nested metadata test | Low | Added explicit "preserves nested metadata values (hashes/arrays)" test case. |
| R3 verification assumes 13 models tests | Low | Non-issue — `t/02-models.rakutest` already has `plan 13`. |
| R4 issue #8 stale path | Low | Updated issue #8 body on GitHub: `Skills/Ref` → `AIgent/Skill`. |
| R5 (2.1) find-skill-md return type (duplicate) | Medium | Same as R1 — addressed. |
| R6 (2.2) closing delimiter underspecified | Low | Specified "a line containing only `---`" for both opening and closing delimiters. |
| R7 (2.3) IO failure on .slurp not tested | Low | Added key decision note: `.slurp` throws `X::IO` naturally; parser only guards missing files, not permission/corruption. |
