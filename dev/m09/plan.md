# Plan: M9 — Claude Code Plugin

## Context

M8 (Main Module & Documentation) is complete. M9 is the final milestone: package aigent as a distributable **Claude Code plugin** with two skills (builder and validator), a plugin manifest, tests, and investigate standalone binary distribution.

Issues: [#34](https://github.com/wkusnierczyk/aigent-skills/issues/34) (builder skill), [#35](https://github.com/wkusnierczyk/aigent-skills/issues/35) (validator skill), [#36](https://github.com/wkusnierczyk/aigent-skills/issues/36) (plugin packaging), [#37](https://github.com/wkusnierczyk/aigent-skills/issues/37) (tests), [#38](https://github.com/wkusnierczyk/aigent-skills/issues/38) (standalone binary — reframed as install script).

## Skill directory conventions

Two distinct paths serve different purposes:

| Path | Purpose | Who writes it |
|------|---------|---------------|
| `skills/aigent-builder/SKILL.md` | Plugin-distributed skill (source, auto-discovered) | Us (this milestone) |
| `.claude/skills/<name>/SKILL.md` | Project-local skill (user-created output) | The builder skill at runtime |

The original issues (#34, #35) reference `.claude/skills/` — that describes where the *builder* writes output for the user, not where the plugin's own skills live. The plugin's skills live at `skills/` per Claude Code plugin convention.

## Plugin Structure

The repo root **is** the plugin root. New files sit alongside existing module code:

```
aigent-skills/                      (existing repo root = plugin root)
├── .claude-plugin/
│   └── plugin.json                 # NEW — plugin manifest
├── skills/
│   ├── aigent-builder/
│   │   └── SKILL.md                # NEW — builder skill (#34)
│   └── aigent-validator/
│       └── SKILL.md                # NEW — validator skill (#35)
├── t/
│   └── 09-plugin.rakutest          # NEW — plugin tests (#37)
├── install.sh                      # NEW — install script (#38)
├── lib/                            (unchanged)
├── bin/                            (unchanged)
└── ...
```

## Issue Sequence

```
#34 (builder skill) ──┐
                       ├── #36 (plugin manifest) ── #37 (tests)
#35 (validator skill) ─┘
#38 (install script) — parallel, independent
```

---

## #34 — aigent-builder skill

**File:** `skills/aigent-builder/SKILL.md`

YAML frontmatter:
```yaml
---
name: aigent-builder
description: >
  Generates AI agent skill definitions from natural language descriptions.
  This skill creates complete SKILL.md files with valid YAML frontmatter
  and structured Markdown body following Anthropic best practices.
  Use when the user asks to "create a skill", "build a skill",
  "generate a skill", or describes a new skill they want to create.
allowed-tools: Bash, Write, Read, Glob
---
```

Body content — hybrid mode instructions:

1. **Detect `aigent` availability:** Run `command -v aigent` via Bash
2. **With `aigent` on PATH (primary):**
   - Assess clarity: `aigent build "<purpose>" --no-llm --dir <output>`
   - If `ANTHROPIC_API_KEY` is set, drop `--no-llm` for richer output
   - Validate output: `aigent validate <output-dir>`
   - Report result path and any warnings
3. **Without `aigent` (fallback):**
   - Use Claude's built-in knowledge of the Anthropic skill spec
   - Generate SKILL.md with proper frontmatter (name, description required; license, compatibility, allowed-tools optional)
   - Name rules: kebab-case, ≤64 chars, no reserved words, gerund form preferred
   - Description: third person, "Use when..." trigger clause, ≤1024 chars
   - Body: overview paragraph, "## When to Use" with bullet triggers, "## Instructions" with numbered steps
   - Write output using Write tool
   - Note: validation was not run (aigent not available)
4. **Output location:** Default to `.claude/skills/<name>/SKILL.md` (project-local skills), or user-specified directory. Both CLI mode (`--dir`) and fallback mode use the same default.

---

## #35 — aigent-validator skill

**File:** `skills/aigent-validator/SKILL.md`

YAML frontmatter:
```yaml
---
name: aigent-validator
description: >
  Validates AI agent skill definitions against the Anthropic agent skill
  best practices specification. Checks SKILL.md frontmatter fields, name
  format, description quality, and structural requirements.
  Use when the user asks to "validate a skill", "check a skill",
  "verify SKILL.md", or wants to ensure a skill follows best practices.
allowed-tools: Bash, Read, Glob
---
```

Body content — hybrid mode:

1. **Detect `aigent`:** `command -v aigent`
2. **With `aigent` (primary):**
   - Run `aigent validate <dir>`
   - Exit 0 = valid, exit 1 = errors printed to stderr
   - Report errors with suggested fixes
3. **Without `aigent` (fallback):**
   - Read the target `SKILL.md` file
   - Check manually against known rules:
     - Frontmatter exists (between `---` delimiters)
     - `name`: present, non-empty, kebab-case, ≤64 chars, no reserved words (anthropic, claude), no leading/trailing/consecutive hyphens
     - `description`: present, non-empty, ≤1024 chars, no XML tags
     - Known optional fields: `license`, `compatibility`, `allowed-tools`, `metadata`
     - Unknown fields flagged
   - Report results and suggest fixes
   - Note: manual check — install aigent for authoritative validation

---

## #36 — Plugin manifest

**File:** `.claude-plugin/plugin.json`

```json
{
  "name": "aigent-skills",
  "description": "AI Agent Skill Builder and Validator. Create and validate SKILL.md definitions following Anthropic best practices.",
  "version": "0.1.0",
  "author": {
    "name": "Waclaw Kusnierczyk",
    "email": "waclaw.kusnierczyk@gmail.com"
  },
  "homepage": "https://github.com/wkusnierczyk/aigent-skills",
  "category": "development"
}
```

No `source` field needed — the repo root is the plugin root, auto-discovery finds `skills/*/SKILL.md`.

**Version sync:** Extend `just version-set` in the justfile to also patch `.claude-plugin/plugin.json` when it exists. This keeps `META6.json` as the single source of truth while ensuring `plugin.json` stays in sync. Test #2 catches drift at CI time as a safety net.

---

## #37 — Plugin tests

**File:** `t/09-plugin.rakutest`

Tests (using existing test patterns from `t/04-validator.rakutest`, `t/08-main.rakutest`):

1. **plugin.json well-formed** — parse as JSON, check required fields (name, description, version, author)
2. **plugin.json version matches META6.json** — single source of truth
3. **Builder SKILL.md exists and parses** — use `read-properties()` from Parser
4. **Builder SKILL.md passes validation** — use `validate()` from Validator (self-validating)
5. **Validator SKILL.md exists and parses** — `read-properties()`
6. **Validator SKILL.md passes validation** — `validate()` (self-validating)
7. **Builder SKILL.md has allowed-tools** — frontmatter contains `allowed-tools`
8. **Validator SKILL.md has allowed-tools** — frontmatter contains `allowed-tools`
9. **Builder body contains `command -v aigent`** — hybrid detection command present
10. **Builder body contains `aigent build`** — CLI invocation present
11. **Validator body contains `command -v aigent`** — hybrid detection command present
12. **Validator body contains `aigent validate`** — CLI invocation present
13. **Both skills mention fallback mode** — body contains fallback/without instructions

Estimated: ~13-15 assertions, `plan N`.

---

## #38 — Standalone binary (reframed → install script)

**Scope change:** The original issue requested standalone binary builds. Research shows this is not feasible in Raku. Issue #38 is reframed as "provide a zero-friction install path for non-Raku users" — achieved via an install script and documented fallback tiers. The issue will be closed with a comment explaining the reframing.

**Research findings:**

Raku does **not** support standalone binary compilation. MoarVM has an [open issue](https://github.com/Raku/old-issue-tracker/issues/5756) but no resolution. Options:

| Approach | Feasibility | Notes |
|----------|------------|-------|
| True standalone binary | ❌ Not available | MoarVM doesn't support it |
| App::InstallerMaker::WiX | Windows only | MSI installer bundling Rakudo + script |
| Bundled tarball (Rakudo + deps) | ⚠️ Fragile | Precomp tied to exact binary; large (~100MB) |
| Install script (`curl \| sh`) | ✅ Practical | Install rakudo-pkg + zef + aigent in one command |
| Docker image | ✅ Practical | For CI/server use cases |
| Prompt-only fallback | ✅ Already planned | Both skills work without aigent installed |

**Recommended approach for #38:**

1. **Create `install.sh`** — installs Rakudo (via rakubrew or rakudo-pkg), then `zef install AIgent::Skill`
2. **Extend `release.yml`** — attach `install.sh` to GitHub Releases as an asset
3. **Recommended install command** uses the release asset URL (pinned to tag), not `main` branch:
   ```bash
   curl -fsSL https://github.com/wkusnierczyk/aigent-skills/releases/latest/download/install.sh | bash
   ```
   This ensures users get the install script matching the release, not HEAD of `main`.
4. **Document three install tiers** in plugin README:
   - Tier 1: Install script (one-liner, recommended)
   - Tier 2: `zef install AIgent::Skill` (for Raku users)
   - Tier 3: No install — prompt-only fallback (both skills work without aigent)
5. **Close #38** with a note explaining why standalone binary is not feasible, and the install script as the practical alternative

---

## Files to create/modify

| File | Action | Issue |
|------|--------|-------|
| `skills/aigent-builder/SKILL.md` | Create | #34 |
| `skills/aigent-validator/SKILL.md` | Create | #35 |
| `.claude-plugin/plugin.json` | Create | #36 |
| `t/09-plugin.rakutest` | Create | #37 |
| `install.sh` | Create | #38 |
| `.github/workflows/release.yml` | Modify — attach install.sh to release assets | #38 |
| `justfile` | Modify — extend `version-set` to sync plugin.json; add install-related targets if needed | #36, #38 |
| `.gitignore` | Add `extracting-data/` pattern — test artifact from builder, should not be tracked | cleanup |

Existing code to reuse:
- `validate()` from `lib/AIgent/Skill/Validator.rakumod` — self-validate skill files in tests
- `read-properties()` from `lib/AIgent/Skill/Parser.rakumod` — parse skill frontmatter in tests
- `parse-frontmatter()` from `lib/AIgent/Skill/Parser.rakumod` — frontmatter extraction
- `JSON::Fast` — parse plugin.json in tests
- Test patterns from `t/08-main.rakutest` (LEAVE cleanup, temp dirs)

---

## Verification

1. **Self-validation:**
   ```bash
   aigent validate skills/aigent-builder
   aigent validate skills/aigent-validator
   ```

2. **Tests:**
   ```bash
   just test                              # full suite including new t/09-plugin.rakutest
   raku -Ilib t/09-plugin.rakutest        # plugin tests only
   ```

3. **Plugin manifest:**
   ```bash
   raku -MJSON::Fast -e 'say from-json(".claude-plugin/plugin.json".IO.slurp).raku'
   ```

4. **Install script (smoke test):**
   ```bash
   bash -n install.sh                     # syntax check
   ```

5. **CI:** Push on `dev/m09` branch, confirm all tests pass on Ubuntu + macOS

---

## PR

Single PR for all 5 issues:
- Branch: `dev/m09`
- Title: `feat: Claude Code plugin with builder and validator skills`
- Body: references #34, #35, #36, #37, #38 with `Closes` directives
- Assigned to wkusnierczyk, labeled, added to project, given M9 milestone

---

## Review resolutions

Findings from `dev/m09/review.md`:

| # | Finding | Resolution |
|---|---------|------------|
| R1-1 | Skill directory layout conflicts (`skills/` vs `.claude/skills/`) | Clarified: `skills/` is plugin source (auto-discovered); `.claude/skills/` is builder output for users. Added convention table. |
| R1-2 | Output location inconsistent (fallback vs default) | Unified: both modes default to `.claude/skills/<name>/SKILL.md`. |
| R1-3 | #38 scope redefined without explicit acceptance criteria | Added "reframed" label and closure note to #38 section. |
| R1-4 | Tests don't assert command snippets in skill bodies | Added tests #9–#12: assert `command -v aigent`, `aigent build`, `aigent validate` present in bodies. |
| R1-5 | `extracting-data/` cleanup left optional | Made explicit: add to `.gitignore`. |
| R2-1 | `plugin.json` version sync not automated | Extend `just version-set` to patch `plugin.json`. Test #2 catches drift as safety net. |
| R2-2 | `install.sh` URL references `main` branch | Changed to release asset URL (`releases/latest/download/install.sh`). |
