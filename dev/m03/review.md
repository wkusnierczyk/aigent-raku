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
