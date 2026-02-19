## Plan review

- Date/time: 2026-02-18 22:04:35 CET
- Branch: `dev/m02` (plan written ahead of `dev/m03`)
- Scope: review of `dev/m03/plan.md`

### Findings

1. Medium: `find-skill-md` return type conflicts with `Nil` return.
   - Plan line 40 signature: `IO::Path $dir --> IO::Path`.
   - Plan line 51 behavior: "Return ... `Nil` if neither exists."
   - In Raku, returning `Nil` from a sub with `--> IO::Path` produces a type-check failure at runtime.
   - Fix options: drop the return type constraint, return an `IO::Path` type object, or use `Failure`.

2. Low: missing explicit test for nested metadata values.
   - Issue #9 specifies "Metadata with nested values" as a test case.
   - Plan test list (line 121) has "Correctly parses metadata into `.metadata` hash" but doesn't explicitly require nested structure.
   - Should include a test with nested YAML values (hashes/arrays) in metadata to verify they're preserved as-is.

3. Low: verification assumes 13 models tests, current suite has 12.
   - Plan line 144 says `02-models: 13`.
   - `t/02-models.rakutest` currently has `plan 12`.
   - This assumes the missing `.metadata` accessor test (M2 CR2 finding 2) will be added — should be noted explicitly or the count corrected.

4. Low: issue #8 body still references old path.
   - Issue body says `lib/Skills/Ref/Parser.rakumod`.
   - Plan correctly uses `lib/AIgent/Skill/Parser.rakumod`.
   - Stale from pre-rename; should be updated on GitHub.

### Findings (2026-02-18 22:05:11 CET)

1. Medium: `find-skill-md` signature still contradicts documented `Nil` behavior.
   - `dev/m03/plan.md:81` declares `sub find-skill-md(IO::Path $dir --> IO::Path)`.
   - `dev/m03/plan.md:92` requires returning `Nil` when no file exists.
   - That combination will type-fail at runtime in Raku; either relax the return type or change the "not found" contract.

2. Low: close-delimiter rule is underspecified and can produce parser ambiguity.
   - `dev/m03/plan.md:100` says "Find the closing `---` after the opening line" but does not require it to be a standalone delimiter line.
   - If implementation uses a naive substring search, embedded `---` in YAML/body can terminate early.
   - Specify "closing delimiter must be a line containing only `---`".

3. Low: tests do not explicitly cover IO failures on `.slurp`.
   - `dev/m03/plan.md:116` requires file read, but test list (`dev/m03/plan.md:53`) has no case for unreadable/corrupt path behavior.
   - Without this, error mapping for read failures may be inconsistent.

## Code review

- Date/time: 2026-02-18 22:53:26 CET
- Branch: `dev/m03`
- Scope: review of parser implementation and tests

### Findings

1. High: module declaration was dropped from `Parser.rakumod`.
   - `lib/AIgent/Skill/Parser.rakumod:1` starts with `use YAMLish;` and has no `unit module AIgent::Skill::Parser;`.
   - `main` had the declaration (`main:lib/AIgent/Skill/Parser.rakumod:1`), so this is a regression in module structure/API.
   - Without a module package, parser subs are compiled in the wrong namespace, which can break qualified symbol access and future package-scoped additions.

2. Medium: frontmatter parsing rejects Windows CRLF files.
   - `lib/AIgent/Skill/Parser.rakumod:18` requires char 4 to be `"\n"` after opening `---`.
   - `lib/AIgent/Skill/Parser.rakumod:29` requires closing delimiter line to be exactly `'---'`.
   - For CRLF (`\r\n`), opening check sees `"\r"`, and closing line becomes `"---\r"`; valid files fail parse on Windows-generated content.

3. Medium: parser API leaks raw IO exceptions instead of parse errors.
   - `lib/AIgent/Skill/Parser.rakumod:8` calls `$dir.dir` directly; missing/unreadable directory throws IO exceptions.
   - `lib/AIgent/Skill/Parser.rakumod:84` calls `$path.slurp` directly; unreadable file throws IO exceptions.
   - Current contract presents parser-specific exceptions (`X::AIgent::Skill::Parse` / `Validation`), but these paths bypass that and return inconsistent exception types.

## Code review 2

- Date/time: 2026-02-18 22:53:45 CET
- Branch: `dev/m03`
- Scope: second-pass review of `main..dev/m03`

### Plan review resolutions

- PR1 / PR-2nd-1 (find-skill-md return type): resolved — return type constraint dropped (`Parser.rakumod:5`).
- PR2 (nested metadata test): resolved — tests at `03-parser.rakutest:124-134` cover nested arrays and hashes.
- PR3 (models test count): resolved — `02-models.rakutest` now has `plan 13` (`.metadata` accessor test added).
- PR-2nd-2 (close-delimiter rule): resolved — `Parser.rakumod:29` uses `eq '---'` (exact line match).
- PR-2nd-3 (IO failures on .slurp): still applicable — covered by CR1 finding 3.

### CR1 findings still open

- CR1-1 (missing module declaration): still present.
- CR1-2 (CRLF rejection): still present.
- CR1-3 (raw IO exceptions): still present.

### New findings

1. Low: dead code on `Parser.rakumod:15`.
   - `my @lines = $content.split("\n", :v);` is assigned but never referenced.
   - Likely a leftover from development. Should be removed.

2. Low: unused `$body` variable in `read-properties`.
   - `Parser.rakumod:87` assigns `my $body = @result[1]` but `$body` is never read.
   - Body is correctly discarded (not part of `SkillProperties`), but the variable should be removed or replaced with a comment noting the intentional discard.

3. Low: `.append` merge strategy can create arrays on key conflicts.
   - `Parser.rakumod:107-108` merges explicit `metadata:` section and unknown top-level keys using `.append`.
   - If both sources share a key, `.append` converts the value to an array instead of one source winning.
   - Edge case in practice, but the behavior should be defined (e.g., explicit `metadata:` takes priority).

4. Low: "prefers uppercase when both exist" test is a tautology on macOS.
   - `03-parser.rakutest:47-55` creates both `SKILL.md` and `skill.md`, but on case-insensitive filesystems (macOS APFS default) the second write targets the same file.
   - Test passes for the wrong reason on macOS. Only meaningful on case-sensitive filesystems (Linux CI).

### Verification

- `just lint` passes (all 8 files compile, META6.json validates).
- `just format` passes.
- `just test` passes (Files=3, Tests=45: errors 11, models 13, parser 21).

### Included commits

- `2617c2d` Merge task/m03-parser: implement Parser module (#8)
- `359d3ad` Implement Parser module (#8)
- `e748b3b` Merge task/m03-tests: add parser tests (#9)
- `967fea2` Add parser tests and API stubs (test-first for #9)
- `4d4e2c3` Add M3 plan and review
