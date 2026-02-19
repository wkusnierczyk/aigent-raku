# M5: Prompt Generation — Work Plan

## Overview

Generate XML prompt output from skill directories. The module reads skill properties from one or more directories and produces an `<available_skills>` XML block suitable for embedding in LLM system prompts.
Issues: #12, #13.

## Branch Strategy

- **Dev branch**: `dev/m05` (created from `main`)
- **Task branches**: `task/m05-<name>` (created from `dev/m05`)
- After each wave, task branches merge into `dev/m05`
- After all waves, draft PR from `dev/m05` → `main`
- `main` is never touched directly
- PR body uses `Closes #N` in the Summary section to auto-close issues on merge (see CLAUDE.md for full format)

## Dependencies

- `AIgent::Skill::Models` — `SkillProperties` (from M2)
- `AIgent::Skill::Parser` — `find-skill-md`, `read-properties` (from M3)

## Waves

### Wave 1 — Tests

Tests first — they define the contract the prompt module must satisfy.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| A | `task/m05-tests` | #13 | Write `t/05-prompt.rakutest` |

**Merge**: A → `dev/m05`. Checkpoint with user.

#### Agent A — Tests (#13)

**`t/05-prompt.rakutest`** (10 tests):

##### `xml-escape` tests:
- Ampersand escaped: `&` → `&amp;`
- Less-than escaped: `<` → `&lt;`
- Greater-than escaped: `>` → `&gt;`
- Double quote escaped: `"` → `&quot;`
- Combined: string with all special chars escaped correctly

##### `to-prompt` tests:
- Empty list → `<available_skills>\n</available_skills>`
- Single skill directory → XML with one `<skill>` element containing `<name>`, `<description>`, `<location>`
- Multiple skill directories → XML with multiple `<skill>` elements in order
- Invalid directory throws `X::AIgent::Skill::Parse` (exception propagates, not caught)
- Skill with special characters in description → XML entities in output (`&` → `&amp;`, `<` → `&lt;`)

Test infrastructure:
- Use `$*TMPDIR.add('aigent-test-' ~ $*PID ~ '-prompt')` for temp directories
- Helper sub to create a valid skill directory with given name and description
- `LEAVE` phaser for cleanup
- For `to-prompt` tests, create real skill directories with SKILL.md files so the full pipeline is exercised (read-properties → XML)

### Wave 2 — Implementation

Make the tests pass.

| Agent | Branch | Issue | Task |
|-------|--------|-------|------|
| B | `task/m05-prompt` | #12 | Implement `lib/AIgent/Skill/Prompt.rakumod` |

**Merge**: B → `dev/m05`. Checkpoint with user.

#### Agent B — Prompt (#12)

Replace the stub `unit module` with:

```raku
sub xml-escape(Str $s --> Str) is export
sub to-prompt(IO::Path @dirs --> Str) is export
```

##### `xml-escape(Str $s --> Str)`

Escape XML special characters:

```
& → &amp;   (must be first to avoid double-escaping)
< → &lt;
> → &gt;
" → &quot;
```

##### `to-prompt(IO::Path @dirs --> Str)`

Generate the `<available_skills>` XML block:

1. For each directory in `@dirs`:
   a. Call `find-skill-md($dir)` to get the actual file path (preserves on-disk casing: `SKILL.md` or `skill.md`)
   b. Call `read-properties($dir)` to get a `SkillProperties`
   c. Generate a `<skill>` element using the properties and the discovered path:
   ```xml
   <skill>
     <name>ESCAPED-NAME</name>
     <description>ESCAPED-DESCRIPTION</description>
     <location>ACTUAL-FILE-PATH</location>
   </skill>
   ```
2. Wrap all `<skill>` elements in `<available_skills>...</available_skills>`
3. Return the complete XML string

Key decisions:
- `to-prompt` accepts `IO::Path @dirs` (typed array). An empty list produces `<available_skills>\n</available_skills>` (no skill elements, just the wrapper).
- `read-properties` may throw `X::AIgent::Skill::Parse` or `X::AIgent::Skill::Validation` for invalid directories. These exceptions are **not caught** by `to-prompt` — they propagate to the caller. This is intentional: prompt generation should fail loudly if a skill directory is invalid, unlike `validate` which collects errors.
- The `<location>` element contains the actual file path as returned by `find-skill-md` — this preserves on-disk casing (`SKILL.md` vs `skill.md`) rather than hardcoding a canonical form. The path is stringified via `.Str` (native OS rendering).
- All text content is XML-escaped via `xml-escape` to prevent XML injection.
- The `<location>` path is also escaped (paths could theoretically contain `&` or `<`).
- Optional fields (license, compatibility, allowed-tools, metadata) and the body are **not** included in the XML output. The prompt format is deliberately minimal — only name, description, and location. This matches the issue #12 spec. The XML serves as a skill catalog/index; consumers needing full instructions read SKILL.md directly.
- Indentation: 2-space indent for `<skill>` elements, 4-space indent for child elements. No trailing newline after closing `</available_skills>`.

### Post-waves

1. Update issue #12 body to fix stale path (`Skills/Ref` → `AIgent/Skill`)
2. Push `dev/m05` to remote
3. Create draft PR `dev/m05` → `main`
4. User reviews and merges when ready

## Verification

After all waves, on `dev/m05`:

```bash
just lint                              # passes
just test                              # all tests pass (01-errors: 11, 02-models: 13, 03-parser: 21, 04-validator: 31, 05-prompt: 10)
raku -Ilib -e '
    use AIgent::Skill::Prompt;
    my @dirs = "/path/to/skill".IO;
    say to-prompt(@dirs);
'
```

## Post-review updates

| Finding | Severity | Resolution |
|---------|----------|------------|
| R1 location path inaccurate vs parser | Medium | `to-prompt` now calls `find-skill-md` to get the actual file path (preserving on-disk casing). Added `find-skill-md` to dependencies. |
| R2 no exception propagation test | Medium | Added test: invalid directory throws `X::AIgent::Skill::Parse`. |
| R3 path format not portable | Low | Specified: location uses native OS rendering via `IO::Path.Str`. Already addressed in R1 fix. |
| R4 no path-escaping test | Low | Added test: skill with special characters in description produces XML entities in output. |
| R2.1 location may not reflect actual filename | Medium | Same as R1 — resolved by using `find-skill-md` instead of hardcoding `SKILL.md`. |
| R2.2 validator test count wrong | Low | Non-issue — `t/04-validator.rakutest` already has `plan 31` (includes unreadable directory test). |
| R2.3 body exclusion | Low | Intentional per issue #12 spec. Added note: XML is a catalog; consumers read SKILL.md for full instructions. |
| R2.4 issue #12 stale path | Low | Confirmed — already in post-waves step 1. |
