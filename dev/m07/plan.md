# M7: Skill Builder

Issues: #16 (data model), #17 (core), #18 (CLI subcommands), #19 (tests), #45 (third-person), #46 (gerund naming), #47 (what+when descriptions), #48 (body length warning), #53 (LLM support)

## Branch Strategy

Branch `dev/m07` from `main`. Single PR to `main` on completion.

## Context

M1–M6 are complete: Errors, Models, Parser, Validator, Prompt, CLI. The Builder module (`lib/AIgent/Skill/Builder.rakumod`) is a stub. M7 implements the Builder — a skill generator that takes a natural language purpose and produces a complete, valid skill directory.

### Dual-Mode Architecture (issue #53)

The Builder supports two generation modes:

| Mode | Trigger | Quality | Dependencies |
|------|---------|---------|-------------|
| **Deterministic** | Default (no config needed) | Formulaic but valid | None |
| **LLM-enhanced** | `ANTHROPIC_API_KEY` env var set | Rich, context-aware | HTTP client + API key |

Mode selection:
- Automatic: if `ANTHROPIC_API_KEY` is set, use LLM mode; otherwise deterministic
- Explicit: `--no-llm` CLI flag forces deterministic mode even when key is available
- Fallback: if LLM call fails (network, auth, rate limit), fall back to deterministic mode with a warning to stderr

Both modes produce output that follows Anthropic best practices (#45–#47). The LLM mode does it better because it can understand context; the deterministic mode uses heuristics and templates.

### Relationship to Spec Compliance

Issues #45–47 define Anthropic best-practice patterns the Builder should follow when generating output:
- #45: third-person descriptions ("Processes...", not "I can help you...")
- #46: gerund naming convention ("processing-pdfs", not "pdf-processor")
- #47: descriptions include what + when ("Does X. Use when Y.")

These are **authoring defaults**, not validation rules. The Builder produces output following these patterns; the Validator does not enforce them.

## Design

### Data Model (issue #16)

Two new classes in `Builder.rakumod`. These are Builder-specific (not general models like `SkillProperties`), so they live in `Builder.rakumod` rather than `Models.rakumod`.

**`SkillSpec`** — captures user input:

| Attribute | Type | Required | Notes |
|-----------|------|----------|-------|
| `purpose` | `Str` | yes | Natural language description of what the skill does |
| `name` | `Str` | no | Override auto-derived name |
| `allowed-tools` | `Str` | no | Desired allowed-tools value |
| `compatibility` | `Str` | no | Compatibility notes |
| `license` | `Str` | no | License string |

CLI flag `--allowed-tools` maps directly to `SkillSpec.allowed-tools` — same name, no translation needed.

**`BuildResult`** — represents the output:

| Attribute | Type | Notes |
|-----------|------|-------|
| `properties` | `SkillProperties` | Generated skill metadata |
| `body` | `Str` | Generated SKILL.md body (markdown) |
| `output-dir` | `IO::Path` | Where files were written |
| `warnings` | `Str @` | Non-fatal warnings (e.g., body length, LLM fallback) |

### LLM Client

Internal helper class, not exported.

**`LLMClient`**:
- `has Str $.api-key` — from `ANTHROPIC_API_KEY` env var
- `has Str $.model` — default from `AIGENT_MODEL` env var, or `'claude-sonnet-4-20250514'`
- `method generate(Str $system-prompt, Str $user-prompt --> Str)` — single-turn completion, returns text content
- Uses `HTTP::UserAgent` via `use` (compile-time import) for HTTPS POST to `https://api.anthropic.com/v1/messages`
- Timeout: 30 seconds
- On failure: throws `X::AIgent::Skill::Build` which callers catch for fallback

**Hard dependency strategy**: `HTTP::UserAgent` is in `META6.json` `depends` and imported via `use` at compile time. This is required because issue #38 plans a standalone compiled binary where all dependencies must be resolved at compile time — `require` (runtime loading) would exclude the HTTP module from the binary.

Deterministic mode still works without an API key — the HTTP client is compiled in but never called unless `ANTHROPIC_API_KEY` is set. The mode decision is a runtime check, not a compile-time one:
- `zef install AIgent::Skill` pulls in `HTTP::UserAgent` (small library, acceptable)
- Deterministic mode works without any API key — HTTP code is present but not invoked
- Standalone binary includes everything needed for both modes

New exception class in `Errors.rakumod`:

```raku
class X::AIgent::Skill::Build is X::AIgent::Skill is export {}
```

### Core Functions (issue #17)

Each core function has a deterministic path and an LLM-enhanced path. The function signature is the same regardless of mode — the mode is selected internally.

**`derive-name(Str $purpose, :$llm --> Str)`**

*Deterministic mode:*

Uses a positional heuristic (not NLP): after stop-word removal, the first remaining word is treated as the verb and the rest as the object. This works well for imperative forms ("Process PDF files") but produces less natural results for other structures ("PDF processing tool"). Acceptable for "formulaic but valid" deterministic mode; LLM mode handles complex structures better.

1. Lowercase, strip punctuation
2. Remove stop words (a, an, the, and, or, for, from, to, with, in, of, that, this, is, are, be, can, will, should)
3. First remaining word → verb → convert to gerund
4. Remaining significant words → object (take first 1–2 words)
5. Join as `{gerund}-{object}` in kebab-case
6. Truncate to 64 chars, trim trailing hyphens

*LLM mode:*
- Prompt the LLM: "Given this purpose, derive a kebab-case skill name in gerund form (e.g., 'processing-pdfs'). Return only the name, nothing else."
- Validate the result (lowercase, ≤64 chars, no reserved words). If invalid, fall back to deterministic.

*Both modes:* If the user provided `name` in `SkillSpec`, use that instead (skip derivation entirely).

Gerund conversion rules (deterministic):
- Already ends in "-ing" → keep as-is
- Ends in "ie" → change to "y" + "-ing" (e.g., "die" → "dying")
- Ends in silent "e" (not "ee"/"ye"/"oe") → drop "e", add "-ing" (e.g., "manage" → "managing")
- Monosyllabic word ending in single vowel + single consonant (excluding w, x, y) → double consonant + "-ing" (e.g., "run" → "running", "stop" → "stopping")
- Default → add "-ing"

The consonant-doubling rule is restricted to monosyllabic words and excludes w/x/y (never doubled in English). This avoids incorrect forms like "fixxing", "showwing", "openning". Multi-syllable stress detection would require NLP, so polysyllabic words use the default rule.

**`generate-description(SkillSpec $spec, :$llm --> Str)`**

*Deterministic mode:*
1. Take the purpose text
2. Ensure it starts with a third-person verb (capitalize first word if needed)
3. If the purpose doesn't contain a "Use when" clause, append a generic one derived from the verb and object: "Use when the user mentions [key terms] or needs [action]."
4. Cap at 1024 chars

*LLM mode:*
- Prompt: "Write a skill description for this purpose. Use third person. Include what the skill does and when to use it ('Use when...'). Keep under 1024 characters. Return only the description."
- Validate length. If > 1024, truncate.

**`generate-body(SkillSpec $spec, :$llm --> Str)`**

*Deterministic mode:*

Template:
```markdown
# {Skill Name in Title Case}

{Purpose expanded into a clear instruction paragraph, written in third person.}

## When to Use

Use this skill when:
- {Trigger condition 1 derived from purpose}
- {Trigger condition 2 if applicable}

## Instructions

When activated, follow these steps:
1. {Step derived from purpose}
2. Validate inputs and handle errors gracefully
3. Return results in a clear, structured format
```

*LLM mode:*
- Prompt: "Generate a SKILL.md body for this skill. Include sections: overview paragraph, '## When to Use' with bullet triggers, '## Instructions' with numbered steps. Write in third person. Be specific to the purpose. Do not include YAML frontmatter."
- The body is returned as-is (LLM-generated markdown).

**`check-body-warnings(Str $body --> List)`**

Separated helper for testability. Checks the body and returns a list of warning strings:
- If body exceeds 500 lines → warning: "SKILL.md body exceeds 500 lines ({N} lines); consider splitting into separate files"
- Returns empty list if no warnings

**`build-skill(SkillSpec $spec, IO::Path $output-dir, :$llm --> BuildResult)`**

Full pipeline:
1. Derive name (or use override)
2. Generate description
3. Generate body
4. Compute skill directory path: `$output-dir.add($name)`
5. If skill directory already exists → throw `X::AIgent::Skill::Build` with message "Directory already exists: {path}". No overwrite, no merge — the user must remove it or choose a different name/dir.
6. Create directory
7. Assemble SKILL.md: YAML frontmatter + body
8. Write SKILL.md
9. Run `validate()` on the output directory — if errors, throw `X::AIgent::Skill::Validation`
10. Check body warnings via `check-body-warnings($body)`
11. Return `BuildResult`

The `:$llm` parameter is an optional `LLMClient` instance. Each sub-function receives it and uses it if defined. If any LLM call fails, the function catches `X::AIgent::Skill::Build`, adds a warning ("LLM unavailable, using deterministic fallback"), and continues with the deterministic path.

**`assess-clarity(Str $purpose, :$llm --> Hash)`**

*Deterministic mode:*
- Length: < 10 chars → unclear ("too short to determine intent")
- No verb detected → unclear ("could not identify the action — what should this skill do?")
- Ambiguous terms only (e.g., "stuff", "things", "handle it") → unclear
- Otherwise → clear

*LLM mode:*
- Prompt: "Evaluate whether this purpose is clear enough to generate an AI agent skill. If unclear, provide 1–3 specific clarifying questions. Respond as JSON: {\"clear\": true/false, \"questions\": [...]}"
- Parse JSON response. If parse fails, fall back to deterministic.

Returns: `{ clear => Bool, questions => Str[] }`

### CLI Subcommands (issue #18)

**`multi MAIN('build', Str $purpose, Str :$name, Str :$dir = '.', Str :$license, Str :$compatibility, Str :$allowed-tools, Bool :$no-llm)`**

1. Determine LLM mode:
   - If `$no-llm` is set, no LLM
   - Else if `%*ENV<ANTHROPIC_API_KEY>` is set, create `LLMClient` (model from `%*ENV<AIGENT_MODEL>` or default)
   - Else no LLM
2. Assess clarity of `$purpose`
3. If unclear, print questions to stderr and exit 1 (no interactive Q&A loop — the user refines their purpose and re-runs)
4. If clear, build the skill:
   - Construct `SkillSpec` from arguments (CLI `--allowed-tools` maps directly to `SkillSpec.allowed-tools`)
   - Call `build-skill($spec, $dir.IO, :$llm)`
   - Print the output directory path to stdout
   - Print any warnings to stderr
5. Error format: `aigent build: <message>` to stderr

**`multi MAIN('init', Str $dir = '.')`**

Minimal scaffolding (always deterministic, no LLM needed):
1. Create directory if it doesn't exist
2. Write a template SKILL.md with placeholder frontmatter and body
3. Print the created file path to stdout
4. If directory already contains SKILL.md → error, do not overwrite
5. Error format: `aigent init: <message>` to stderr

Template:
```yaml
---
name: my-skill
description: Describe what this skill does. Use when [trigger conditions].
---
# My Skill

Describe the skill's behavior and instructions here.
```

### Body Length Warning (issue #48)

Integrated into `build-skill` via `check-body-warnings` helper. The CLI prints warnings to stderr.

Not added to `validate()` in this milestone — that would require changing the validate return type (separate lint function, per #48 discussion). Keeping it builder-only for now.

## Wave 1: Tests (`t/07-builder.rakutest`)

Test file: `t/07-builder.rakutest` (renumbered from plan's `06-builder` since CLI tests took `06`).

All tests use **deterministic mode** (no API key, no mocking needed) except test #22 which injects a mock failing client to test the LLM fallback path.

### Test cases (23 assertions)

**derive-name (5 assertions)**
1. Simple purpose → gerund name: "Process PDF files" → "processing-pdfs"
2. Purpose with stop words stripped: "Extract text from documents" → "extracting-documents"
3. Silent-e verb: "Manage database connections" → "managing-databases"
4. Already gerund: "Running tests automatically" → "running-tests"
5. Truncation: very long purpose → name ≤ 64 chars

**generate-description (3 assertions)**
6. Produces third-person description starting with a verb
7. Includes "Use when" clause
8. Does not exceed 1024 chars

**generate-body (2 assertions)**
9. Contains expected markdown sections (# heading, ## When to Use, ## Instructions)
10. Contains purpose-derived content

**check-body-warnings (2 assertions)**
11. Short body → empty warnings list
12. Body with >500 lines → warning list contains length message

**assess-clarity (3 assertions)**
13. Clear purpose → `{ clear => True, questions => [] }`
14. Too-short purpose → `{ clear => False, questions => [...] }`
15. Ambiguous purpose → `{ clear => False, questions => [...] }`

**build-skill (4 assertions)**
16. Full build produces valid directory with SKILL.md
17. Generated SKILL.md passes `validate()`
18. BuildResult contains correct properties
19. Build into existing directory → throws `X::AIgent::Skill::Build`

**CLI: build (3 assertions)**
20. `aigent build "Process PDF files"` → exit 0, stdout contains output path
21. `aigent build "x"` → exit 1, stderr contains clarity question
22. `aigent build "Process PDF files" --no-llm` → exit 0 (deterministic forced)

**CLI: init (1 assertion)**
23. `aigent init $dir` → exit 0, creates SKILL.md template

**LLM fallback (1 assertion — removed, folded into build-skill)**

Note: the old test #22 ("build without API key succeeds") is redundant — all build-skill tests already run without an API key. The new test #19 (existing dir collision) replaces it as a more valuable assertion. LLM failure fallback is tested by injecting a mock client that always throws in test #17 or a dedicated unit test if needed.

## Wave 2: Implementation

### Step 1: Error class (`Errors.rakumod`)
1. Add `X::AIgent::Skill::Build` exception class

### Step 2: Data model (`Builder.rakumod`)
2. Define `SkillSpec` class with attributes (including `allowed-tools`)
3. Define `BuildResult` class with attributes

### Step 3: LLM client (`Builder.rakumod`)
4. Implement `LLMClient` class (internal, not exported, `use HTTP::UserAgent`)

### Step 4: Core functions (`Builder.rakumod`)
5. Implement `derive-name` with gerund conversion (deterministic + LLM paths)
6. Implement `generate-description` with third-person + what/when pattern (deterministic + LLM paths)
7. Implement `generate-body` with template filling (deterministic + LLM paths)
8. Implement `check-body-warnings` helper
9. Implement `assess-clarity` with heuristic checks (deterministic + LLM paths)
10. Implement `build-skill` — full pipeline with post-validation, collision check, and LLM fallback

### Step 5: CLI (`bin/aigent`)
11. Add `multi MAIN('build', ...)` candidate with `--no-llm` flag
12. Add `multi MAIN('init', ...)` candidate
13. Update USAGE sub with new commands

### Step 6: README
14. Update status line: "**M7 (Skill Builder) complete.**"

No changes to Validator, Parser, Prompt, or Models (except adding `X::AIgent::Skill::Build` to Errors).

## Verification

```bash
just test    # all tests pass (112 existing + 23 new = 135)
just lint    # all files compile, META6.json valid
```

Manual smoke test:
```bash
d=$(mktemp -d)
raku -Ilib bin/aigent build "Process PDF files and extract text" --dir "$d"
ls "$d"/processing-pdfs/SKILL.md
raku -Ilib bin/aigent validate "$d/processing-pdfs"
raku -Ilib bin/aigent read-properties "$d/processing-pdfs"

raku -Ilib bin/aigent build "Analyze spreadsheet data" --no-llm --dir "$d"
raku -Ilib bin/aigent validate "$d/analyzing-spreadsheets"

e=$(mktemp -d)/my-new-skill
raku -Ilib bin/aigent init "$e"
cat "$e/SKILL.md"

rm -rf "$d" "$(dirname "$e")"
```

## Post-review updates

| Finding | Severity | Resolution |
|---------|----------|------------|
| PR1-1: `use` vs `require` inconsistency | Medium | Fixed: `use HTTP::UserAgent` (hard dep in `META6.json`); required for standalone binary (#38). Mode selection is runtime (API key check), not compile-time |
| PR1-2: LLM fallback test doesn't test failure | Medium | Reorganized: old test #22 removed (redundant), collision test added; LLM fallback tested via mock injection if needed |
| PR1-3: `tools` vs `allowed-tools` naming | Medium | Fixed: renamed `SkillSpec.tools` → `SkillSpec.allowed-tools`; direct CLI mapping documented |
| PR1-4: Branch naming wording | Low | Fixed: "Branch `dev/m07`" instead of "Task branch" |
| PR1-5: Collision behavior unspecified | Medium | Fixed: error on existing directory, no overwrite/merge |
| PR2-1: Gerund consonant-doubling oversimplified | Medium | Fixed: restricted to monosyllabic words, excluded w/x/y |
| PR2-2: Confirms `require` needed (overlap PR1-1) | Medium | Resolved with PR1-1 — but went with `use` instead (standalone binary requirement) |
| PR2-3: Test #17 untestable deterministically | Medium | Fixed: extracted `check-body-warnings` helper, tested directly with synthetic body |
| PR2-4: Existing dir behavior (overlap PR1-5) | Medium | Resolved with PR1-5 |
| PR2-5: SkillSpec/BuildResult in Builder vs Models | Low | Kept in Builder — intentional, Builder-specific classes |
| PR2-6: Positional verb heuristic not NLP | Low | Stated explicitly in plan text |
| PR2-7: Model ID hardcoded | Low | Fixed: `AIGENT_MODEL` env var override added |
| PR2-8: Confirms naming mismatch (overlap PR1-3) | Low | Resolved with PR1-3 |
