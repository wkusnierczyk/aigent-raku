## Plan review

- Date/time: 2026-02-19
- Scope: review of `dev/m04/plan.md`

### Findings

1. Medium: `validate` “never throws” guarantee is not fully specified for IO failures.
   - `dev/m04/plan.md:110` says `validate` converts parser exceptions to error strings and always returns a list.
   - The pipeline at `dev/m04/plan.md:104`-`dev/m04/plan.md:107` implies manual file read + `parse-frontmatter`; that can still raise non-parser IO exceptions unless explicitly wrapped.
   - Update needed: specify that file read errors are caught and converted to validation error strings too (or route through parser helpers that already wrap IO errors).

2. Medium: unknown-field policy is ambiguous in executable test coverage.
   - The plan says unknown keys are errors (`dev/m04/plan.md:145`), but Wave 1 tests do not explicitly include an unknown-key rejection case (`dev/m04/plan.md:39`-`dev/m04/plan.md:53`).
   - Update needed: add a direct test case for unknown top-level fields to lock this behavior.

3. Medium: required-field type validation is described but not explicitly tested.
   - Implementation notes require non-empty strings for `name` and `description` and string type for `compatibility` (`dev/m04/plan.md:116`, `dev/m04/plan.md:127`, `dev/m04/plan.md:132`).
   - Current test bullets mostly cover missing/length/format (`dev/m04/plan.md:40`-`dev/m04/plan.md:52`).
   - Update needed: add tests for wrong YAML types (e.g., `name: 123`, `description: []`, `compatibility: {}`) so parser+validator behavior is deterministic.

4. Low: name-regex guidance is internally inconsistent.
   - `dev/m04/plan.md:122` lists a `\w`-based option and a Unicode-category option, while key decisions say not to use `\w` (`dev/m04/plan.md:142`).
   - Update needed: keep only the `<:L>/<:N>/-` form to avoid implementation drift.

5. Low: test count remains approximate while behavior list is precise.
   - `dev/m04/plan.md:37` and `dev/m04/plan.md:160` use `~21`, but the test matrix is detailed enough to be concrete.
   - Update needed: either pin an exact expected count or state explicitly that count is intentionally approximate and non-blocking.

## Plan review 2

- Date/time: 2026-02-19 08:08:46 CET
- Scope: review of `dev/m04/plan.md`

### Overall

Plan is solid. Tests-first ordering (Wave 1 tests, Wave 2 implementation) addresses the earlier test-methodology concern. Validator design (never throws, collects all errors as strings) is clean and well-justified. Dependencies are correct against the current M3 codebase.

### Findings

1. Low: NFKC normalization path is uncertain.
   - Plan line 117 uses `$name.NFKC.Str` with a hedge "(or `use Unicode::Normalize` if needed)."
   - In Raku, `Str.NFKC` may return a `Uni` that doesn't round-trip cleanly to `Str` in all Rakudo versions.
   - Should verify in implementation and have a concrete fallback ready rather than discovering the issue mid-wave.

2. Low: "invalid characters" test lists two examples in one bullet.
   - Plan line 48: `my_skill`, `my skill` — unclear if this is one test or two.
   - Affects total count (~21 or ~22). Minor, but the test plan should be unambiguous.

3. Low: issue #10 body still references old path `lib/Skills/Ref/Validator.rakumod`.
   - Plan line 149 already notes this as a post-wave fix. Confirmed.

## Code review

- Date/time: 2026-02-19 08:23:41 CET
- Branch: `dev/m04`
- Scope: code review of `main..dev/m04`

### Plan review resolutions

- PR1-1 (IO failures in validate): resolved — `Validator.rakumod:146-149` has a `default` CATCH that wraps all non-Parse exceptions as error strings.
- PR1-2 (unknown-field test): resolved — test #15 (`04-validator.rakutest:141-147`) explicitly tests unknown field rejection.
- PR1-3 (type validation tests): resolved — tests #16-18 (`04-validator.rakutest:149-168`) cover wrong YAML types for name, description, and compatibility.
- PR1-4 (name-regex inconsistency): resolved — `Validator.rakumod:47` uses only `<:L>/<:N>/-` form.
- PR1-5 (approximate test count): resolved — `plan 30` is exact.
- PR2-1 (NFKC normalization): resolved — `.NFKC.Str` works; NFKC test (#26) passes with fi ligature.
- PR2-2 (invalid chars ambiguity): resolved — underscore and space are separate tests (#9, #10).

### New findings

1. Low: NFKC normalization not applied to directory basename in name comparison.
   - `Validator.rakumod:21` normalizes the name via `.NFKC.Str`.
   - `Validator.rakumod:52` compares `$name ne $dir.basename` where `$dir.basename` is not normalized.
   - If a directory name contains NFKC-equivalent characters (e.g., ligatures), the comparison fails even though the names are semantically equivalent.
   - Unlikely in practice, but inconsistent with the normalization rationale.

2. Low: `done-testing` is redundant with `plan 30`.
   - `04-validator.rakutest:5` declares `plan 30` and line 241 calls `done-testing`.
   - With an explicit plan, `done-testing` is unnecessary. Harmless but noisy.

3. Low: YAML serialization helper is fragile for complex values.
   - `04-validator.rakutest:16-22` manually serializes YAML. Values containing colons, hashes, or other YAML-special characters won't be quoted; nesting deeper than one level isn't handled.
   - Fine for current tests (simple values), but will break if future tests add complex frontmatter.

### Verification

- `just lint` passes (all 8 files compile, META6.json validates).
- `just format` passes.
- `just test` passes (Files=4, Tests=75: errors 11, models 13, parser 21, validator 30).
- README status updated to "M3 (Parser) complete."

### Included commits

- `c34ee47` Merge task/m04-validator: implement Validator module (#10)
- `207d66a` Implement Validator module (#10)
- `d517c77` Merge task/m04-tests: add validator tests (#11)
- `d4a8e71` Add validator tests and API stubs (test-first for #11)
- `3355eac` Add M4 plan and review

## Code review 2

- Date/time: 2026-02-19
- Branch: `dev/m04`
- Scope: code review of `main..dev/m04`

### Findings

1. Medium: `validate` can still throw on unreadable directories, violating its "never throws" contract.
   - `lib/AIgent/Skill/Validator.rakumod:129` calls `find-skill-md($dir)` before entering the `try`/`CATCH` at `lib/AIgent/Skill/Validator.rakumod:137`.
   - `find-skill-md` throws `X::AIgent::Skill::Parse` when directory listing fails (permission denied). Because this happens outside `try`, the exception escapes from `validate`.
   - Repro used during review: create directory with mode `000` and call `validate($dir)`; observed thrown exception `X::AIgent::Skill::Parse: Cannot read directory ... permission denied`.
   - Expected behavior (per plan and module comments): return `List` of error strings, not throw.

### Testing gaps

- No test currently covers unreadable directory permission errors in `validate`; add one in `t/04-validator.rakutest` to prevent regression.

### Verification

- `just test` passes (`Files=4, Tests=75`).
- `just lint` passes.
