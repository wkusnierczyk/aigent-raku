
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

## Code review

- Date/time: 2026-02-19 12:20:18 CET
- Branch: `dev/m07`
- Scope: code review of `main..dev/m07`

### Findings

1. Medium: `assess-clarity` does not implement its own "no verb detected" rule.
   - `lib/AIgent/Skill/Builder.rakumod:291`-`lib/AIgent/Skill/Builder.rakumod:296` labels the check as "No verb detected" but only verifies that any non-stopword exists.
   - Noun-only purposes (for example, `"PDF documents"`) return `{ clear => True }`, which contradicts the declared deterministic criteria for unclear input.
   - Repro used during review: `raku -Ilib -e 'use AIgent::Skill::Builder; say assess-clarity("PDF documents").raku'` returned `{:clear(Bool::True), :questions($[])}`.

2. Medium: LLM fallback path can produce inconsistent output (directory name vs body title) and emits no fallback warning.
   - `build-skill` derives the canonical name once (`lib/AIgent/Skill/Builder.rakumod:312`), but deterministic `generate-body` recomputes a name from purpose instead of using the chosen output name (`lib/AIgent/Skill/Builder.rakumod:229`).
   - When the first LLM call succeeds (name) and later calls fail (fallback), output directory uses LLM name while body heading uses deterministic name.
   - Repro used during review with a sequential mock LLM: output dir basename `custom-skill`, body first line `# Processing Pdf Files`.
   - Related: fallback is silent; `build-skill` declares warning plumbing (`lib/AIgent/Skill/Builder.rakumod:309`, `lib/AIgent/Skill/Builder.rakumod:360`) but no LLM-fallback warning is ever added.

### Testing gaps

1. Low: no test covers noun-only "no verb" clarity behavior.
   - Current clarity tests in `t/07-builder.rakutest:140`-`t/07-builder.rakutest:159` cover clear/too-short/ambiguous only.

2. Low: no test covers partial LLM failure consistency/fallback warning behavior.
   - Builder tests run deterministic path only; there is no mock-based test for "name from LLM, later generation fallback" consistency.

### Verification

- `just test` passes (`Files=7, Tests=135`).
- `just lint` passes.

## Code review 2

- Date/time: 2026-02-19
- Branch: `dev/m07` (411bcba)
- Scope: full `main..dev/m07` diff — 5 agents, confidence-scored

### CLAUDE.md compliance

No issues. All conventions satisfied: kebab-case subs, `X::AIgent::Skill::Build` hierarchy, module/test paths, version in META6.json only.

### Findings

No issues scored >= 80 (high confidence). The following scored 75 and are worth attention:

1. Medium: YAML injection in manually assembled frontmatter.
   - `lib/AIgent/Skill/Builder.rakumod:346-348`: `license`, `compatibility`, `allowed-tools` are emitted unquoted. `description` is correctly single-quoted. Values containing `:`, `#`, `[` (e.g. `--license "MIT: Apache"`) produce invalid YAML, breaking `validate()`.
   - Fix: apply the same `'{$val.subst("'","''", :g)}'` quoting to all scalar fields.

2. Medium: `HTTP::UserAgent.post` called with JSON body as bare positional.
   - `lib/AIgent/Skill/Builder.rakumod:51-57`: `to-json(%body)` is passed as a positional argument after header pairs. `HTTP::UserAgent.post` expects form data or named `content =>` for raw body. The JSON likely won't reach the API.
   - Untested because all tests use `--no-llm`. Will fail at runtime in LLM mode.

3. Medium: `generate-body` recomputes name without `:$llm` (confirmed in prior review).
   - `lib/AIgent/Skill/Builder.rakumod:229` vs `lib/AIgent/Skill/Builder.rakumod:312`. Body heading diverges from directory name in LLM mode.

4. Medium: LLM fallback warnings mandated by plan but not emitted (confirmed in prior review).
   - Every `CATCH { when X::AIgent::Skill::Build { } }` block silently swallows. Plan line 183 requires warning.

5. Low: plan test expectations stale.
   - Plan specifies `"processing-pdfs"`, `"managing-databases"` but implementation produces `"processing-pdf-files"`, `"managing-database-connections"` (`.head(2)` takes 2 object words). Plan smoke test (`ls "$d"/processing-pdfs/SKILL.md`) would fail.

### Items verified clean

- `assess-clarity` verb-detection gap: confirmed from prior review, unchanged.
- CLI success-path tests not checking stderr: M6 tests are inconsistent on this, so not a convention violation.
- USAGE comment ("stdout, exit 2"): empirically correct — `say` goes to stdout.
- `derive-name` nil guard: unnecessary, `return 'new-skill'` covers empty case.
