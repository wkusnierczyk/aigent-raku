
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
