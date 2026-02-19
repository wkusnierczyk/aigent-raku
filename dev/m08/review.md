
## Plan review

- Date/time: 2026-02-19 14:10:44 CET
- Scope: review of `dev/m08/plan.md`

### Findings

1. Medium: proposed `AIgent::Skill` re-export mechanism is likely incorrect.
   - Plan states that `use` in `lib/AIgent/Skill.rakumod` will automatically re-export imported `is export` symbols to downstream consumers (`dev/m08/plan.md`, "Implementation" under deliverable 1).
   - In Raku, `use` imports symbols into the current lexical scope; it does not automatically make parent-module consumers receive those symbols unless explicitly exported by the parent.
   - Update needed: define an explicit re-export strategy and verify with `t/08-main.rakutest` before assuming this wiring works.

2. Medium: test-count math in the plan is stale.
   - Plan says `just check` should pass with `136 existing + ~16 new` (`dev/m08/plan.md`, "Test plan").
   - Current baseline is already 135 tests in M7 (`just test` on current branch), so adding ~16 gives ~151, not 152+.
   - Update needed: recalculate expected totals to keep verification criteria accurate.

3. Low: release-notes extraction can silently produce empty notes.
   - Workflow extracts CHANGES content via `awk` keyed on `## $VERSION` (`dev/m08/plan.md`, release workflow section).
   - If CHANGES heading format drifts (e.g., `## [0.1.0]`), release notes become empty without hard failure.
   - Update needed: add a guard step that fails the workflow when `release_notes.md` is empty.

4. Low: README plan item "CI matrix updated (no Windows)" conflicts with current README and should be called out as intentional migration.
   - Current README still documents a 3-OS matrix including Windows (`README.md`, CI section), while current workflow is Ubuntu+macOS only (`.github/workflows/ci.yml`).
   - The M8 README rewrite should explicitly align docs to the actual CI config to avoid another drift cycle.

## Plan review 2

- Date/time: 2026-02-19
- Scope: review of `dev/m08/plan.md`

### Findings

1. High: re-export mechanism is confirmed broken — empirically verified.
   - Plan claims (`dev/m08/plan.md:72-75`): "In Raku, `use` inside a module automatically re-exports all `is export` symbols."
   - Tested in isolation: `unit module Foo; use Foo::Bar;` where `Foo::Bar` exports `sub greet` and `class Widget`. Consumer `use Foo; greet()` fails with "Undeclared routine: greet."
   - Direct import (`use Foo::Bar; greet()`) works fine — confirming `is export` works, but transitive re-export does not.
   - This blocks deliverable #1 entirely. The verification commands (`dev/m08/plan.md:79-83`) would fail.
   - Fix: use an explicit `sub EXPORT()` that returns a hash of symbols, or have consumers `use AIgent::Skill::Parser` etc. directly (umbrella module becomes documentation-only).

2. Low: "Task branch" wording repeated.
   - `dev/m08/plan.md:8`: "Task branch `dev/m08` from `main`".
   - M7 plan review flagged this (PR1-4) and it was fixed to "Branch `dev/m07`". M8 repeats the old form.

3. Low: issue #24 scope discrepancy with full plan.
   - `dev/plan.md:141` (full plan): "#24 Add GitHub Actions release workflow — ... publish to Raku ecosystem (zef)."
   - `dev/m08/plan.md:215-216`: "No ecosystem publishing for now."
   - Intentional deferral, but the full plan issue description should be updated to match.

### Items verified clean

- CHANGES.md format and awk extraction: correct for single-version file with `###` subsections.
- Release workflow: `prove6` without Just is appropriate (simpler, no setup-just dependency for releases).
- Re-export list matches actual M7 implementation exports (no stale or missing symbols).
- Implementation order (lines 261-266): sensible — main module first, version bump last.
- Smoke test uses `processing-pdf-files` (line 282), matching actual `derive-name` output (not the stale plan value `processing-pdfs`).

## Code review

- Date/time: 2026-02-19 14:45:49 CET
- Branch: `dev/m08`
- Scope: code review of `main..dev/m08`

### Findings

1. Medium: `AIgent::Skill` module namespace is no longer declared.
   - `lib/AIgent/Skill.rakumod:1` starts with imports and `EXPORT` but no `unit module AIgent::Skill;` declaration.
   - Practical impact: `use AIgent::Skill` works for symbol imports, but the module type object is missing (`::("AIgent::Skill")` resolves undefined), which can break reflection/introspection use cases and is inconsistent with other compunits.

2. Medium: README validation section documents behaviors the validator does not implement.
   - `README.md:218` says description must be at least 10 characters; validator only enforces non-empty + max length.
   - `README.md:219` says reserved words are forbidden as field names; implementation forbids reserved words in the **skill name value**.
   - `README.md:241` marks "Body ≤ 500 lines warning" as validator/spec-compliance behavior; this warning is currently builder-only (`check-body-warnings`) and not part of `validate`.

3. Low: README API contract claims unsupported builder parameters.
   - `README.md:272` says all builder functions accept optional `:@warnings`.
   - Current builder APIs expose `:$llm`; no exported function accepts `:@warnings`.

### Verification

- `just test` passes (`Files=8, Tests=152`).
- `just lint` passes.

## Code review 2

- Date/time: 2026-02-19
- Branch: `dev/m08` (a57fa6c)
- Scope: code review of `main..dev/m08`

### Findings

1. Low: README reserved-words link points to wrong page.
   - `README.md:219`: "No [Anthropic reserved words](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) as field names"
   - URL is the prompt caching docs, not reserved words. And the actual rule is about the name *value* containing "anthropic"/"claude", not about field names.

2. Low: `done-testing` redundant after `plan 16`.
   - `t/08-main.rakutest:149`: `done-testing` is a no-op when `plan N` is declared (line 5).

### Plan review resolutions

| Plan finding | Status |
|---|---|
| PR1-1: re-export mechanism broken | Fixed: `sub EXPORT()` with explicit symbol map. `unit module` dropped as required. |
| PR1-2: test count stale | Resolved: 152 actual (136 M1-M7 + 16 M8). The M7 baseline was 135 on `dev/m07` but 136 after merge to main. |
| PR1-3: empty release notes | Fixed: guard added (`if [ ! -s release_notes.md ]; then ... exit 1`). |
| PR1-4: CI matrix docs drift | Fixed: README now documents Ubuntu + macOS only with Raku/REA#7 note. |
| PR2-1: re-export confirmed broken | Fixed (same as PR1-1). |
| PR2-2: "Task branch" wording | Fixed in plan: `dev/m08/plan.md:7` now says "Branch `dev/m08`". |
| PR2-3: issue #24 scope | Documented in plan: explicit note about deferred ecosystem publishing. |

### Items verified clean

- `sub EXPORT()` maps all 22 symbols (4 exceptions, 3 classes, 9 subs from Parser/Validator/Prompt, 6 subs from Builder). Matches the plan's re-export list exactly.
- Release workflow: correct `actions/checkout@v4`, `Raku/setup-raku@v1`, `softprops/action-gh-release@v2`.
- CHANGES.md: format matches awk extraction pattern.
- META6.json: version bumped to 0.1.0, keys reordered alphabetically, `provides` includes all modules.
- Blog post (`posts/raku-windows-ci-max-path.md`): informational, documents Windows CI investigation. No code impact.
- Test fixture cleanup: both LEAVE blocks handle their temp dirs correctly.

### Code review resolutions

| Code finding | Status |
|---|---|
| CR1-1: module namespace missing | Fixed: added `module AIgent::Skill {}` block declaration alongside `sub EXPORT()`. |
| CR1-2: README validation rules inaccurate | Fixed: corrected README validation rules section and rewrote spec compliance table comparing all three sources (Anthropic spec, Python reference, Raku). Description ≥10 chars was not in the official spec or Python reference, so was not added. |
| CR1-3: README claims unsupported `:@warnings` | Fixed: added `:@warnings` to `check-body-warnings` and `build-skill`. README note clarified (`check-body-warnings` doesn't accept `:$llm`). |
| CR2-1: reserved-words link wrong | Fixed: URL updated to best practices page, description corrected. |
| CR2-2: redundant `done-testing` | Fixed: removed from `t/08-main.rakutest`. |

### Verification

- `just test` passes (`Files=8, Tests=152`).
- `just lint` passes.
