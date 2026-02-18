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
