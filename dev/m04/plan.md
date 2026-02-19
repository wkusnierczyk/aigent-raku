# M4: Validator — Work Plan

## Overview

Implement validation of skill directories and metadata against the specification. The validator enforces semantic rules beyond what the parser checks: name format, length limits, directory name matching, and Unicode normalization.
Issues: #10, #11.

## Branch Strategy

- **Dev branch**: `dev/m04` (created from `main`)
- **Task branches**: `task/m04-<name>` (created from `dev/m04`)
- After each wave, task branches merge into `dev/m04`
- After all waves, draft PR from `dev/m04` → `main`
- `main` is never touched directly
- PR body uses `Closes #N` in the Summary section to auto-close issues on merge (see CLAUDE.md for full format)

## Dependencies

- `AIgent::Skill::Errors` — `X::AIgent::Skill::Parse`, `X::AIgent::Skill::Validation` (from M2)
- `AIgent::Skill::Models` — `SkillProperties` (from M2)
- `AIgent::Skill::Parser` — `find-skill-md`, `parse-frontmatter`, `read-properties` (from M3)

## Waves

### Wave 1 — Tests

Tests first — they define the contract the validator must satisfy.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| A | `task/m04-tests` | #11 | Write `t/04-validator.rakutest` |

**Merge**: A → `dev/m04`. Checkpoint with user.

#### Agent A — Tests (#11)

**`t/04-validator.rakutest`** (26 tests):

##### `validate-metadata` tests (metadata-level validation):
- Valid metadata hash returns no errors
- Missing `name` returns error
- Missing `description` returns error
- Name: uppercase letters rejected (`My-Skill`)
- Name: too long (>64 chars) rejected
- Name: leading hyphen rejected (`-my-skill`)
- Name: trailing hyphen rejected (`my-skill-`)
- Name: consecutive hyphens rejected (`my--skill`)
- Name: underscore rejected (`my_skill`)
- Name: space rejected (`my skill`)
- Name: directory mismatch rejected (name is `foo` but dir is `bar/`)
- Description: too long (>1024 chars) rejected
- Compatibility: too long (>500 chars) rejected
- All known optional fields accepted (license, compatibility, allowed-tools, metadata)
- Unknown top-level field rejected (`frobnicate: yes` → error)
- Name with wrong YAML type rejected (`name: 123` → error)
- Description with wrong YAML type rejected (`description: [a, b]` → error)
- Compatibility with wrong YAML type rejected (`compatibility: {x: 1}` → error)

##### `validate` tests (full directory validation):
- Valid skill directory returns no errors
- Nonexistent path returns error
- Path is a file, not a directory, returns error
- Missing SKILL.md returns error

##### i18n tests:
- Chinese characters in name accepted (`数据分析`)
- Russian with hyphens accepted (`анализ-данных`)
- Uppercase Cyrillic rejected (`Анализ`)
- NFKC normalization: compatibility-equivalent characters normalized before validation

Test infrastructure:
- Use `$*TMPDIR.add('aigent-test-' ~ $*PID ~ '-val')` for temp directories
- Helper sub to write a SKILL.md with given frontmatter into a temp directory
- `LEAVE` phaser for cleanup

### Wave 2 — Implementation

Make the tests pass.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| B | `task/m04-validator` | #10 | Implement `lib/AIgent/Skill/Validator.rakumod` |

**Merge**: B → `dev/m04`. Checkpoint with user.

#### Agent B — Validator (#10)

Replace the stub `unit module` with exported subs and internal helpers:

```raku
sub validate-metadata(%metadata, IO::Path $dir? --> List) is export
sub validate(IO::Path $dir --> List) is export
```

##### `validate-metadata(%metadata, IO::Path $dir? --> List)`

Returns a list of error strings (empty list = valid). Runs all field checks:

1. Call `validate-name(%metadata, $dir)` — collects name errors
2. Call `validate-description(%metadata)` — collects description errors
3. Call `validate-compatibility(%metadata)` — collects compatibility errors
4. Call `validate-metadata-fields(%metadata)` — collects unknown field errors
5. Return flattened list of all errors

##### `validate(IO::Path $dir --> List)`

Full directory validation pipeline:

1. Check `$dir` exists and is a directory — return error if not
2. Call `find-skill-md($dir)` — return error if `Nil`
3. Read the file (`.slurp`) and call `parse-frontmatter` — inside a `try`/`CATCH` block
4. Call `validate-metadata(%metadata, $dir)` with the parsed metadata and directory
5. Return all collected errors (from parsing + validation)

IO failure contract: `validate` wraps the entire file-read + parse pipeline in a `try`/`CATCH` that catches `X::AIgent::Skill::Parse` (which already wraps raw IO errors per M3's CR1-3 fix) and any other `Exception`. All caught exceptions are converted to error strings. The caller always gets a flat list of strings — `validate` never throws.

##### Internal helpers

**`validate-name(%metadata, IO::Path $dir? --> List)`**

1. Check `name` exists and is a non-empty string → error if missing
2. Apply NFKC normalization: `$name = $name.NFKC.Str` (verified: Raku's built-in `.NFKC` returns a `NFKC` type that round-trips cleanly via `.Str` — "ﬁlter" → "filter", "⑤star" → "5star", CJK unchanged)
3. Max 64 characters → error if exceeded
4. Must be all lowercase: `$name eq $name.lc` → error if not (this works for Unicode because `.lc` handles Cyrillic, etc.)
5. Must not start or end with hyphen → error
6. Must not contain consecutive hyphens (`/\-\-/`) → error
7. Must contain only letters, digits, and hyphens: `/^ [<:L> | <:N> | '-']+ $/` → error if not
8. If `$dir` is provided: `$name eq $dir.basename` → error if mismatch

**`validate-description(%metadata --> List)`**

1. Check `description` exists and is a non-empty string → error if missing
2. Max 1024 characters → error if exceeded

**`validate-compatibility(%metadata --> List)`**

1. If `compatibility` is present, check it is a string → error if wrong type
2. Max 500 characters → error if exceeded

**`validate-metadata-fields(%metadata --> List)`**

1. Known keys: `set <name description license compatibility allowed-tools metadata>`
2. Any key not in the set → warning/error for each unknown key

Key decisions:
- NFKC normalization is applied to the `name` field before all other name checks. This ensures compatibility-equivalent Unicode sequences (e.g., ligatures, fullwidth characters) are treated consistently.
- The name character class uses `<:L>` (Unicode letter) and `<:N>` (Unicode number) plus hyphen, NOT `\w` (which includes underscore). This allows Chinese, Cyrillic, Arabic, etc. while rejecting underscores and spaces.
- `validate` never throws — it returns a list of error strings. This is different from the parser which throws exceptions. The validator is designed for "collect all errors" mode so users can fix everything at once.
- `validate-metadata` accepts an optional `$dir` parameter — when present, it also checks that the name matches the directory basename. When absent (e.g., validating metadata in isolation), directory matching is skipped.
- Unknown fields are reported as errors, not silently ignored — this prevents typos in field names from going unnoticed.

### Post-waves

1. Update issue #10 body to fix stale path (`Skills/Ref` → `AIgent/Skill`)
2. Push `dev/m04` to remote
3. Create draft PR `dev/m04` → `main`
4. User reviews and merges when ready

## Verification

After all waves, on `dev/m04`:

```bash
just lint                              # passes
just test                              # all tests pass (01-errors: 11, 02-models: 13, 03-parser: 21, 04-validator: 26)
raku -Ilib -e '
    use AIgent::Skill::Validator;
    my @errors = validate("/path/to/skill".IO);
    say @errors ?? @errors.join("\n") !! "Valid!";
'
```

## Post-review updates

| Finding | Severity | Resolution |
|---------|----------|------------|
| R1 IO failure handling in `validate` | Medium | Specified full exception-catching contract: `validate` wraps file-read + parse in `try`/`CATCH` that catches `X::AIgent::Skill::Parse` and any other `Exception`, converting all to error strings. |
| R2 missing unknown-field test | Medium | Added "Unknown top-level field rejected" test case to `validate-metadata` tests. |
| R3 missing wrong-type tests | Medium | Added 3 tests: `name: 123`, `description: [a, b]`, `compatibility: {x: 1}` — covers non-string YAML types for required/typed fields. |
| R4 inconsistent regex | Low | Removed `\w`-based regex option. Only `<:L>/<:N>/-` form remains. |
| R5 approximate test count | Low | Pinned exact count: 26 tests (18 validate-metadata + 4 validate + 4 i18n). |
| R2.1 NFKC round-trip | Low | Verified: `$name.NFKC.Str` works cleanly in current Rakudo. Removed hedge about `Unicode::Normalize`. |
| R2.2 invalid-chars ambiguity | Low | Split into two tests: underscore (`my_skill`) and space (`my skill`). |
| R2.3 issue #10 stale path | Low | Confirmed — already listed as post-wave step 1. |
