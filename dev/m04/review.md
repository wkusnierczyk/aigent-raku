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
