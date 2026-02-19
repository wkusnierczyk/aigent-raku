
## Plan review

- Date/time: 2026-02-19 08:51:43 CET
- Scope: review of `dev/m05/plan.md`

### Findings

1. Medium: `<location>` contract is inaccurate vs parser behavior.
   - `dev/m05/plan.md:96` and `dev/m05/plan.md:105` specify `<location>DIR-PATH/SKILL.md</location>` and call it "the actual file that was read".
   - Current parser can read either `SKILL.md` or `skill.md` (`lib/AIgent/Skill/Parser.rakumod:18`-`lib/AIgent/Skill/Parser.rakumod:19`).
   - Update needed: either constrain implementation to always emit the actual discovered filename, or explicitly state output is canonicalized and may differ from on-disk casing.

2. Medium: exception propagation is a key contract but has no explicit Wave 1 test.
   - Plan says `to-prompt` intentionally does not catch `read-properties` exceptions (`dev/m05/plan.md:104`).
   - Test list (`dev/m05/plan.md:45`-`dev/m05/plan.md:48`) only covers happy paths.
   - Update needed: add at least one test that invalid input directory causes `to-prompt` to throw `X::AIgent::Skill::Parse`/`X::AIgent::Skill::Validation`.

3. Low: path-format wording is not portable across platforms.
   - The plan hardcodes slash form (`DIR-PATH/SKILL.md`) at `dev/m05/plan.md:96`.
   - Project test matrix includes Windows; path stringification can vary by OS.
   - Update needed: define whether `<location>` uses native path rendering or normalized `/` separators, and test accordingly.

4. Low: XML-escaping requirement for `<location>` is stated but not represented in test bullets.
   - Plan requires escaping location text (`dev/m05/plan.md:107`), but `to-prompt` test bullets don't mention a path-escaping case (`dev/m05/plan.md:45`-`dev/m05/plan.md:48`).
   - Update needed: add a test case with escapable characters in path/name to lock this behavior.

## Plan review 2

- Date/time: 2026-02-19 08:51:31 CET
- Scope: review of `dev/m05/plan.md`

### Overall

Compact plan for a focused module. Tests-first ordering is good. XML format is clear and the key decisions (minimal output, exceptions propagate, escape all text) are well-justified.

### Findings

1. Medium: `<location>` path may not reflect actual filename.
   - Plan line 105: "directory path with `/SKILL.md` appended (the actual file that was read)."
   - If the file on disk is `skill.md` (lowercase), hardcoding `SKILL.md` produces an incorrect location.
   - `read-properties` doesn't expose the resolved file path; `to-prompt` would need to call `find-skill-md` separately or the plan should define a canonical form.
   - Overlaps with PR1 finding 1; confirming the issue from a different angle.

2. Low (resolved): verification count lagged the validator tests at the time of this review.
   - Plan line 124 says `04-validator: 31`.
   - At the time of this review, `t/04-validator.rakutest` had `plan 30`; it has since been updated to `plan 31`.
   - The unreadable-directory test from M4 CR2 has been added, fulfilling the dependency.

3. Low: `to-prompt` XML excludes body content.
   - Plan line 108 explicitly excludes optional fields and body — only name, description, and location.
   - The Python reference `to-prompt` may include the body (skill instructions) in the XML.
   - Worth confirming this matches the intended use case: without body, the XML is an index/catalog, not a full prompt injection. If downstream consumers need the body, they must read SKILL.md separately.

4. Low: issue #12 body still references old path `lib/Skills/Ref/Prompt.rakumod`.
   - Plan line 113 notes this for post-wave fix. Confirmed.

## Code review

- Date/time: 2026-02-19 09:29:16 CET
- Branch: `dev/m05`
- Scope: code review of `main..dev/m05`

### Findings

No functional defects or regressions found in this delta.

### Residual risks / testing gaps

1. Low: no explicit test that `<location>` is XML-escaped.
   - `lib/AIgent/Skill/Prompt.rakumod:33` escapes location via `xml-escape($path.Str)`.
   - `t/05-prompt.rakutest` validates description escaping (`t/05-prompt.rakutest:113`) but not a path containing escapable characters.

2. Low: no explicit test for lowercase `skill.md` path preservation in `<location>`.
   - Implementation resolves path via `find-skill-md` (`lib/AIgent/Skill/Prompt.rakumod:26`) and serializes it (`lib/AIgent/Skill/Prompt.rakumod:33`).
   - Current tests only create `SKILL.md` (`t/05-prompt.rakutest:19`).

### Verification

- `just test` passes (`Files=5, Tests=86`).
- `just lint` passes.

## Code review 2

- Date/time: 2026-02-19 09:28:48 CET
- Branch: `dev/m05`
- Scope: second-pass review of `main..dev/m05`

### Plan review resolutions

- PR1-1 / PR2-1 (`<location>` path): resolved — `Prompt.rakumod:26` calls `find-skill-md($dir)` to get the actual discovered path; `Prompt.rakumod:33` emits `$path.Str`, reflecting real filename casing.
- PR1-2 (exception propagation test): resolved — test #9 (`05-prompt.rakutest:105-111`) verifies invalid directory throws `X::AIgent::Skill::Parse`.
- PR1-4 (XML-escape test for location): partially addressed — test #10 tests special chars in description, but not in the path/location itself.
- PR2-2 (validator test count): resolved — `t/04-validator.rakutest` has `plan 31` on main.
- PR2-3 (body content exclusion): implementation matches plan — no body in XML. Design decision stands.

### CR1 findings still open

- CR1-1 (no location XML-escape test): still present, confirmed by this review.
- CR1-2 (no lowercase `skill.md` location test): still present, confirmed by this review.

### New findings

1. Low: `find-skill-md` is called twice per directory.
   - `Prompt.rakumod:26` calls `find-skill-md($dir)` for the location path.
   - `Prompt.rakumod:27` calls `read-properties($dir)` which internally calls `find-skill-md` again.
   - Each directory is scanned twice. Negligible cost but redundant.

2. Low: `Nil` path is not explicitly guarded.
   - `Prompt.rakumod:26` assigns `$path = find-skill-md($dir)` which can return `Nil`.
   - Line 27's `read-properties($dir)` throws before `$path` is used on line 33, so `Nil` never reaches XML output.
   - Correct by ordering, but fragile — reordering or removing the `read-properties` call would allow `Nil` to slip into the XML as the string `"Nil"`.

### Verification

- `just lint` passes (all 8 files compile, META6.json validates).
- `just format` passes.
- `just test` passes (Files=5, Tests=86: errors 11, models 13, parser 21, validator 31, prompt 10).

### Included commits

- `fd679a3` Merge task/m05-prompt into dev/m05
- `16457ac` Implement Prompt module with xml-escape and to-prompt
- `7a29ef2` Merge task/m05-tests into dev/m05
- `ead278c` Add tests for Prompt module (10 assertions)
- `e7e9da0` Add M5 plan and review for Prompt Generation module
