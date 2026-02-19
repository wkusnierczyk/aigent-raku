
## Plan review

- Date/time: 2026-02-19 11:19:10 CET
- Scope: review of `dev/m07/plan.md`

### Findings

1. Medium: LLM dependency/loading strategy is internally inconsistent and left unresolved.
   - Plan says HTTP dependency is added to `META6.json` (`dev/m07/plan.md:222`) but also says the module should load fine without it and only fail in LLM path.
   - In Raku, `use` is compile-time; without a concrete lazy-load strategy (`require`/late binding), this can break deterministic-only usage.
   - `dev/m07/plan.md:224` defers the decision, but this needs to be fixed before implementation because it affects module load behavior.

2. Medium: LLM fallback contract is not actually covered by proposed tests.
   - Architecture requires fallback on LLM call failure with warning (`dev/m07/plan.md:25`, `dev/m07/plan.md:162`).
   - Test #22 only checks behavior when API key is absent (`dev/m07/plan.md:269`-`dev/m07/plan.md:270`), which is just deterministic mode, not failure fallback.
   - Update needed: add a test that simulates LLM failure (e.g., injected failing client) and asserts deterministic fallback plus warning emission.

3. Medium: `SkillSpec` field naming is inconsistent with CLI/API naming.
   - Data model defines `tools` (`dev/m07/plan.md:50`), while CLI uses `--allowed-tools` (`dev/m07/plan.md:180`).
   - Mapping from CLI flag to `SkillSpec` attribute is not specified, which can cause dropped/incorrect frontmatter output.
   - Update needed: standardize on one name (`allowed-tools`/`allowed_tools`/`tools`) and document exact mapping.

4. Low: branch strategy wording is inconsistent with earlier milestone conventions.
   - `dev/m07/plan.md:7` says "Task branch `dev/m07` from `main`"; `dev/m07` is a milestone/dev branch, not a task branch name.
   - Not blocking, but confusing when compared with prior plans that separate dev and task branches.

5. Low: manual smoke test assumes overwrite behavior that is not specified.
   - The script builds into the same output root twice for essentially the same derived name (`dev/m07/plan.md:311`, `dev/m07/plan.md:316`).
   - Plan does not define whether existing target dirs are overwritten, merged, or rejected.
   - Update needed: specify collision behavior in `build-skill` and align smoke test accordingly.

## Plan review 2

- Date/time: 2026-02-19 11:30:00 CET
- Scope: review of `dev/m07/plan.md`

### Findings

1. Medium: gerund conversion consonant-doubling rule is oversimplified.
   - Plan rule (`dev/m07/plan.md:104`): "Single vowel + single consonant (short syllable) → double consonant + `-ing`".
   - English consonant-doubling applies only to stressed final CVC syllables, excluding final w, x, y.
   - The rule as stated would produce incorrect forms:
     - "fix" → "fixxing" (correct: "fixing" — x is never doubled)
     - "show" → "showwing" (correct: "showing" — w is never doubled)
     - "play" → "playying" (correct: "playing" — y is never doubled)
     - "open" → "openning" (correct: "opening" — final syllable is unstressed)
   - Update needed: at minimum, exclude w/x/y from doubling and restrict to monosyllabic words (since stress detection requires NLP). This covers the common cases without overcomplicating the heuristic.

2. Medium: conditional HTTP dependency loading requires `require`, not `use`.
   - Overlaps with PR1 finding 1; confirming from implementation angle.
   - Raku's `use` is a compile-time directive. `use HTTP::UserAgent` at the top of `Builder.rakumod` would fail to compile if the package isn't installed, regardless of whether LLM mode is active.
   - Must use `require HTTP::UserAgent` (runtime loading) to achieve conditional imports.
   - This also contradicts adding it to `META6.json` `depends` (`dev/m07/plan.md:222`), which makes it a hard dependency installed by `zef install`. If it's in `depends`, the "module loads fine without it" scenario only occurs for manual installs without dependency resolution.
   - Update needed: specify `require` for runtime loading and decide whether the dependency is hard (in `depends`) or soft (not in `depends`, graceful error if missing).

3. Medium: test #17 (long body >500 lines) appears untestable with deterministic mode.
   - The deterministic body template is ~15 lines (`dev/m07/plan.md:126–143`).
   - No purpose string would cause the fixed template to expand to >500 lines.
   - No injection, mock, or override mechanism is described for controlling body output.
   - Update needed: describe how to exercise the warning path. Options: (a) add a `:body` override to `SkillSpec` so tests can inject a long body, (b) split the body-length check into a separately-testable helper, or (c) test `BuildResult.warnings` directly with a manually constructed result.

4. Medium: `build-skill` does not specify behavior when the output directory already exists.
   - Overlaps with PR1 finding 5; confirming.
   - Plan step 4: "Create directory named after the skill inside `$output-dir`" (`dev/m07/plan.md:155`).
   - If the directory already exists (e.g., re-running build with the same purpose), behavior is undefined: overwrite, error, or generate a unique name.
   - Update needed: define the overwrite/error policy.

5. Low: `SkillSpec` and `BuildResult` in `Builder.rakumod` rather than `Models.rakumod`.
   - Existing convention: data model classes live in `Models.rakumod` (e.g., `SkillProperties`).
   - `dev/plan.md:123` lists `SkillSpec` and `BuildResult` as M8 re-exports alongside `SkillProperties`, treating them as peer model classes.
   - Placing them in `Builder.rakumod` breaks the established pattern. May be intentional (Builder-specific), but worth confirming.

6. Low: `derive-name` "extract the main verb and object" is positional heuristic, not NLP.
   - Plan step 3 (`dev/m07/plan.md:92`): "First remaining word → verb" / "Remaining significant words → object".
   - No POS tagging or NLP dependency. This is "first word after stop-word removal is verb, rest is object".
   - Works for imperative forms ("Process PDF files") but produces poor results for other structures ("PDF processing tool").
   - Acceptable for "formulaic but valid" deterministic mode, but plan should state the positional assumption explicitly.

7. Low: LLM model ID is hardcoded with no CLI override.
   - `claude-sonnet-4-20250514` (`dev/m07/plan.md:69`) is the only option.
   - If the model is deprecated or unavailable, LLM mode fails with no recourse except a code change.
   - Consider adding a `--model` CLI flag or `AIGENT_MODEL` env var.

8. Low: `SkillSpec.tools` vs CLI `--allowed-tools` naming mismatch.
   - Overlaps with PR1 finding 3; confirming.
   - Data model defines attribute `tools` (`dev/m07/plan.md:50`), CLI uses `--allowed-tools` (`dev/m07/plan.md:180`).
   - The mapping between CLI flag name and `SkillSpec` attribute is not specified.
   - Update needed: either rename the attribute to `allowed-tools` to match CLI and `SkillProperties`, or document the explicit mapping.
