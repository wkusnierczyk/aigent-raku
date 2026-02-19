
## Plan review

- Date/time: 2026-02-19 15:43:37 CET
- Scope: review of `dev/m09/plan.md`

### Findings

1. Medium: skill directory layout conflicts with the project’s own M9 definition.
   - This plan places skills under `skills/...` (`dev/m09/plan.md:17`-`dev/m09/plan.md:21`, `dev/m09/plan.md:42`, `dev/m09/plan.md:80`).
   - The canonical milestone plan expects `.claude/skills/...` for issues #34/#35 (`dev/plan.md:147`-`dev/plan.md:148`).
   - Update needed: pick one layout and align all paths (plugin structure, file list, verification commands, and issue descriptions).

2. Medium: output-location guidance is internally inconsistent.
   - Builder fallback says write to `skills/<derived-name>/SKILL.md` (`dev/m09/plan.md:72`).
   - Immediately after, default output location says `.claude/skills/<name>/` (`dev/m09/plan.md:74`).
   - Update needed: define a single default path and keep it consistent across builder/validator skills and tests.

3. Medium: #38 scope is redefined without explicit acceptance criteria update.
   - `dev/plan.md` defines #38 as standalone binary delivery (`dev/plan.md:149`).
   - This plan replaces it with install-script research outcome (no binary), which is pragmatic, but changes issue scope (`dev/m09/plan.md:160`-`dev/m09/plan.md:187`).
   - Update needed: explicitly mark #38 as "de-scoped/reframed" in plan acceptance criteria and in issue tracking to avoid closure ambiguity.

4. Low: plugin tests validate metadata and text hints, but not runnable workflow contracts.
   - Proposed tests check parsing/validation/body mentions (`dev/m09/plan.md:144`-`dev/m09/plan.md:155`).
   - They do not assert key executable instructions (e.g., `command -v aigent`, `aigent build`, `aigent validate`) are actually present in skill bodies.
   - Update needed: add assertions for required command snippets so hybrid-mode behavior can’t drift silently.

5. Low: local repo currently has untracked `extracting-data/` artifact and plan leaves cleanup optional.
   - Plan notes `.gitignore` update as "possibly" (`dev/m09/plan.md:202`), but workspace already contains such artifact patterns.
   - Update needed: make cleanup decision explicit (ignore pattern vs delete fixture outputs) to avoid accidental commits.

## Plan review 2

- Date/time: 2026-02-19
- Scope: review of `dev/m09/plan.md`

### Findings

1. Medium: `plugin.json` version sync not automated.
   - Plan hardcodes `"version": "0.1.0"` in `.claude-plugin/plugin.json` (`dev/m09/plan.md:124`).
   - `just version-set` only updates `META6.json`. After any version bump, `plugin.json` drifts silently.
   - Test #2 catches the mismatch at CI time, but the plan should specify how to keep them in sync (e.g., extend `just version-set` to also patch `plugin.json`).

2. Low: `install.sh` URL references `main` branch.
   - `dev/m09/plan.md:179`: `raw.githubusercontent.com/.../main/install.sh`
   - Users following this during a release get HEAD of `main` (which could be ahead of the tagged release). Should reference the tag or use a stable redirect.

### Items verified clean

- Skill YAML frontmatter: both skills have `name`, `description`, `allowed-tools`. Names are kebab-case, ≤64 chars, no reserved words. Descriptions include "Use when" triggers.
- Hybrid mode design: detect → CLI primary → prompt-only fallback is sound. Both skills document the complete fallback rules.
- Self-validation tests (#4, #6): running `validate()` on the skill directories is a good self-consistency check.
- Issue sequence: #34/#35 parallel → #36 → #37. #38 independent. Correct.
- Standalone binary research: correctly identifies MoarVM limitation, proposes practical alternatives.
- PR convention: branch `dev/m09`, assigned to wkusnierczyk, `Closes` directives. Matches established pattern.
