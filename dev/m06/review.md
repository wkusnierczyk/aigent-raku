
## Plan review

- Date/time: 2026-02-19 10:02:41 CET
- Scope: review of `dev/m06/plan.md`

### Findings

1. Medium: verification test-count math is wrong.
   - Plan says `just test` should be `88 existing + 16 new = 104` (`dev/m06/plan.md:154`).
   - Current suite is `86` tests (11 + 13 + 21 + 31 + 10), so with 16 new it should be `102`.
   - Update needed: correct the expected total to avoid false failure during verification.

2. Medium: `USAGE`/no-args behavior is underspecified and test assumes Raku default semantics.
   - Test #15 expects no args to be non-zero and stderr contains `Usage` (`dev/m06/plan.md:122`).
   - Implementation section also says to keep custom `USAGE` text (`dev/m06/plan.md:72`) and update it (`dev/m06/plan.md:146`), but does not define whether no-args path goes through custom `USAGE` or compiler-generated usage.
   - Update needed: define exact no-args behavior (custom handler vs default MAIN dispatch), then test exact output accordingly.

3. Low: error-output section has conflicting drafts before final rule.
   - It first proposes command-prefixed errors for all commands (`dev/m06/plan.md:31`-`dev/m06/plan.md:35`), then revises to bare errors for `validate` (`dev/m06/plan.md:39`-`dev/m06/plan.md:44`).
   - Final rule is reasonable, but the earlier block reads as active spec.
   - Update needed: remove superseded text and keep only final output contract.

4. Low: `--about` metadata key naming should align with `META6.json` fields.
   - Plan output example uses `licence` spelling (`dev/m06/plan.md:66`), while metadata key is `license` in `META6.json:6`.
   - This may be intentional display text, but implementation instructions should explicitly map fields (`auth`, `source-url`, `license`) to labels to avoid drift.

## Plan review 2

- Date/time: 2026-02-19 10:02:34 CET
- Scope: review of `dev/m06/plan.md`

### Findings

1. Medium: `multi MAIN('--about')` won't match standard Raku CLI argument parsing.
   - Plan line 123 suggests `multi MAIN('--about')` as one option.
   - Raku's built-in MAIN dispatch parses `--about` as a named Bool parameter (`about => True`), not as the positional string `'--about'`.
   - `multi MAIN('--about')` would never be reached.
   - The plan also suggests `:$about` named param — that is the correct approach. Should commit to it and drop the string-literal option.
   - Same concern applies to the existing `multi MAIN('--help')` on `bin/aigent:7` — likely dead code (Raku auto-triggers `USAGE` on `--help`).

2. Low: `resolve-skill-dir` case-insensitivity mismatches parser.
   - Plan line 23: case-insensitive check for `skill.md` / `SKILL.md`.
   - Parser (`find-skill-md`) uses exact-case matching (`'SKILL.md' ∈ @entries`).
   - A file named `Skill.md` or `SKILL.MD` would be resolved by the CLI helper but not found by the parser. Should align: either both case-insensitive or both exact-case.

3. Low: issue #14 body still references `bin/skills-ref` (stale from pre-rename).

4. Low: no formal branch strategy section.
   - Previous M2–M5 plans had a `## Branch Strategy` section with task branch naming.
   - M6 plan omits this. Doesn't block execution but breaks convention.

5. Low: plan text includes internal deliberation as prose.
   - Lines 62-64 (test numbering), lines 28-42 (error format) show thinking-aloud.
   - Overlaps with PR1 finding 3. Should be cleaned before implementation.
