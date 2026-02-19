
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

2. Low: verification assumes 31 validator tests, current suite has 30.
   - Plan line 124 says `04-validator: 31`.
   - `t/04-validator.rakutest` has `plan 30`.
   - Likely anticipates the unreadable-directory test from M4 CR2; should note dependency or correct the count.

3. Low: `to-prompt` XML excludes body content.
   - Plan line 108 explicitly excludes optional fields and body — only name, description, and location.
   - The Python reference `to-prompt` may include the body (skill instructions) in the XML.
   - Worth confirming this matches the intended use case: without body, the XML is an index/catalog, not a full prompt injection. If downstream consumers need the body, they must read SKILL.md separately.

4. Low: issue #12 body still references old path `lib/Skills/Ref/Prompt.rakumod`.
   - Plan line 113 notes this for post-wave fix. Confirmed.
