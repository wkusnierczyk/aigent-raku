## Plan review

- Date/time: 2026-02-18 17:34:12 CET
- Branch: `dev/m01` (plan written ahead of `dev/m02`)
- Scope: review of `dev/m02/plan.md`

### Findings

1. Medium: metadata type mismatch between issue and plan.
   - Issue #6 specifies `Hash[Str, Str]` (flat string-to-string).
   - Plan (line 99) uses `has %.metadata` (untyped Hash).
   - Issue #9 (M3 parser tests) mentions "metadata with nested values", which contradicts `Hash[Str, Str]`.
   - Needs a decision: flat `Hash[Str, Str]` or untyped `Hash`?

2. Medium: auto-close convention conflicts with PR format.
   - Plan line 15 says "PR uses `Closes #N` for auto-closing issues on merge."
   - `CLAUDE.md` PR format specifies bare `#N` refs, which link but do not trigger auto-close.
   - Either drop the auto-close claim, or define where `Closes #N` goes in the PR body.

3. Low: redundant `method message` on base exception.
   - Plan lines 66-68: `has Str $.message` already auto-generates a `message` accessor.
   - The explicit `method message(--> Str) { $!message }` is a no-op and can be removed.
   - The `Validation` subclass override is fine (different behavior).

4. Low: README status line is stale.
   - `README.md` says "Planning complete. Implementation not yet started."
   - M1 is merged, so this is inaccurate.
   - Not listed in the rename scope — could be included there since the plan already touches README.

## Code Review 1

- Date/time: 2026-02-18 18:18:36 CET
- Branch: `dev/m02`
- Scope: code review of `main..dev/m02`

### Findings

1. Medium: README points to two different repos and includes a stale clone path.
   - `README.md:55`, `README.md:56`, and `README.md:135` still reference `raku-skills-ref`.
   - `META6.json:7` and current `origin` use `aigent-skills`.
   - This can break onboarding and creates source-of-truth ambiguity.

2. Medium: README documents `--about`, but CLI does not implement it.
   - `README.md:101` says the `--about` option reads version at runtime.
   - `bin/aigent:7` only defines `--help`.
   - `raku -Ilib bin/aigent --about` exits non-zero and prints usage.

3. Low: `AIgent::Skill::Errors` compunit does not declare its module namespace.
   - `lib/AIgent/Skill/Errors.rakumod:1` defines classes directly without `unit module AIgent::Skill::Errors;`.
   - `use AIgent::Skill::Errors` works for loading classes, but `::("AIgent::Skill::Errors")` is not defined, unlike other modules.

### Verification

- `just lint` passes.
- `just test` passes (`Files=2, Tests=23`).
- `just format` passes.

### Included commits

- `9325430` Expand CI to run on Linux, macOS, and Windows matrix
- `c93fc5f` Merge task/m02-tests: add tests for Errors and Models (#7)
- `2a68369` Add tests for Errors and Models modules
- `2ed9010` Merge task/m02-models: implement SkillProperties class (#6)
- `7046ebd` Merge task/m02-errors: implement exception hierarchy (#5)
- `75fa90b` Implement SkillProperties class in AIgent::Skill::Models
- `e37b058` Implement exception hierarchy in AIgent::Skill::Errors
- `5eb6343` Merge task/m02-rename: rename Skills::Ref → AIgent::Skill (#33)
- `17c0111` Rename module namespace from Skills::Ref to AIgent::Skill
- `91cae70` Add M2 plan, M9 milestone, and address plan review findings

## Code Review 2

- Date/time: 2026-02-18 18:21:47 CET
- Branch: `dev/m02`
- Scope: code review of `main..dev/m02`

### Plan review resolutions

- PR1 (metadata type): resolved — implemented as untyped `has %.metadata`.
- PR2 (auto-close convention): resolved — `CLAUDE.md` updated to `Closes #N` format.
- PR3 (redundant method message): resolved — `Errors.rakumod:1-3` has only `has Str $.message`, no redundant explicit method.
- PR4 (stale README status): resolved — `README.md:17` now says "M1 complete. M2 in progress."

### CR1 findings still open

- CR1-1 (stale repo URLs): still present. Additional instances in README milestone table — lines 119, 121-126 use `raku-skills-ref` URLs while lines 120, 127 use `aigent-skills`.
- CR1-2 (--about not implemented): still present, unchanged.
- CR1-3 (Errors module namespace): still present, unchanged.

### New findings

1. Low: `dev/plan.md:1` title is stale.
   - Says "Raku Skills-Ref Implementation Plan" — should reflect the rename to `AIgent::Skill`.

2. Low: `t/02-models.rakutest` missing `.metadata` accessor test.
   - M2 plan line 154 specifies "`.metadata` accessor returns hash" as a test case.
   - Not covered. Test count still reaches 12 because `.name` and `.description` are two separate assertions (plan lists them as one item).

3. Low: CI Windows matrix not verified.
   - `ci.yml:18` adds `windows-latest` to the matrix.
   - `justfile:1` sets `shell := ["bash", ...]`; recipes use `find` and bash scripts.
   - Windows GHA runners have Git Bash, but path handling and cache paths (`~/.raku`, `~/.zef`) may not work as expected.
   - No CI run on this branch yet to confirm.

### Verification

- `just lint` passes (all 8 files compile, META6.json validates).
- `just format` passes (no whitespace issues).
- `just test` passes (Files=2, Tests=23).
- Old `lib/Skills/` directory removed.
- Remote is `git@github.com:wkusnierczyk/aigent-skills.git`.

### Included commits

Same as Code Review 1 (no new commits).
