# M6: CLI

Issues: #14 (CLI), #15 (tests), #26 (--about)

## Branch Strategy

Task branch `m06/cli` from `main`. Single PR to `main` on completion.

## Context

M2–M5 are complete: Errors, Models, Parser, Validator, Prompt. The CLI (`bin/aigent`) is a stub with a `USAGE` sub and a dead `multi MAIN('--help')` handler. M6 wires up the three core subcommands plus `--about`, with integration tests.

## Design

### Subcommands

| Subcommand | Module call | stdout | stderr | exit |
|------------|-------------|--------|--------|------|
| `validate <dir>` | `validate($dir)` → `List` | (none) | error messages, one per line | 0 if empty, 1 if errors |
| `read-properties <dir>` | `read-properties($dir)` → `SkillProperties` | JSON via `.to-hash` + `to-json` | exception `.message` | 0 / 1 |
| `to-prompt <dir>...` | `to-prompt(@dirs)` → `Str` | XML | exception `.message` | 0 / 1 |
| `--about` | reads META6.json | project stanza | (none) | 0 |

### Path resolution

Helper `resolve-skill-dir(Str $path --> IO::Path)`:
- If `$path` is a file named exactly `SKILL.md` or `skill.md` (exact-case, matching `find-skill-md`), return parent dir
- Otherwise return `$path.IO`
- Applied to every `$skill-dir` argument before dispatching to modules

Note: uses exact-case matching to align with `find-skill-md` in Parser, which checks `'SKILL.md' ∈ @entries` and `'skill.md' ∈ @entries`. A file named `Skill.md` or `SKILL.MD` will not trigger resolution.

### Error output format

- `validate`: bare error strings to stderr, one per line (matches validator's `List` of strings, keeps output parseable)
- `read-properties` / `to-prompt`: `aigent <cmd>: <message>` to stderr

### --about

Reads META6.json at runtime using `$?DISTRIBUTION` or `%?RESOURCES`, or falls back to reading the file from `$*PROGRAM.parent(2).add('META6.json')`. Outputs:

```
AIgent::Skill: Raku AI Agent Skills Tool
├─ version:    0.0.1
├─ developer:  github:wkusnierczyk
├─ source:     https://github.com/wkusnierczyk/aigent-skills.git
└─ license:    MIT https://opensource.org/licenses/MIT
```

Field mapping from META6.json keys to display labels:
- `version` → `version`
- `auth` → `developer`
- `source-url` → `source`
- `license` → `license`

### USAGE / no-args behavior

Raku's built-in `multi MAIN` dispatch handles `--help` and no-args automatically:
- `--help`: Raku calls `USAGE()` and exits 0
- No args: Raku prints `USAGE()` to stderr and exits non-zero (exit 2)

There is no need for a `multi MAIN('--help')` candidate — that is dead code because Raku parses `--help` as a named Bool parameter and auto-triggers `USAGE` before dispatch. The existing `multi MAIN('--help')` will be removed.

Custom `USAGE` sub provides the help text. Remove `build` and `init` lines (M7, not yet implemented). Add `--about`.

## Wave 1: Tests (`t/06-cli.rakutest`)

Test file: `t/06-cli.rakutest`.

### Process execution helper

```raku
sub run-cli(*@args --> List) {
    my $proc = run 'raku', '-Ilib', 'bin/aigent', |@args,
                   :out, :err;
    my $stdout = $proc.out.slurp(:close);
    my $stderr = $proc.err.slurp(:close);
    my $exit   = $proc.exitcode;
    ($exit, $stdout, $stderr);
}
```

Uses synchronous `run` (simpler than `Proc::Async`, sufficient for CLI tests).

### Skill dir helper

Reuse the same pattern as previous test files:
```raku
sub make-skill-dir(Str $name, Str $description --> IO::Path) { ... }
```

### Test cases (16 assertions)

**validate (4 assertions)**
1. Valid skill dir → exit 0, empty stderr
2. Invalid skill (uppercase name) → exit 1, stderr contains "must be lowercase"
3. Nonexistent dir → exit 1, stderr mentions path
4. SKILL.md file path → resolves to parent, exit 0 (smart path resolution)

**read-properties (4 assertions)**
5. Valid skill → exit 0, stdout is valid JSON with correct name
6. Valid skill with optional fields → JSON includes license
7. Invalid dir → exit 1, non-empty stderr
8. JSON output matches expected structure (parse and check keys)

**to-prompt (4 assertions)**
9. Single dir → exit 0, stdout contains `<available_skills>` and `<skill>`
10. Multiple dirs → exit 0, stdout contains both skill names
11. Invalid dir → exit 1, non-empty stderr
12. SKILL.md file path → resolves to parent, exit 0, correct XML

**--about (2 assertions)**
13. `--about` → exit 0, stdout contains "AIgent::Skill"
14. `--about` → stdout contains version from META6.json

**USAGE (2 assertions)**
15. No args → exit non-zero, stderr contains "Usage"
16. `--help` → exit 0, stdout contains "validate"

## Wave 2: Implementation (`bin/aigent`)

1. Add imports: `use AIgent::Skill::Parser`, `Validator`, `Prompt`, `Errors`, `JSON::Fast`
2. Remove dead `multi MAIN('--help')` candidate
3. Implement `resolve-skill-dir` helper (exact-case `SKILL.md`/`skill.md` only)
4. Implement `multi MAIN('validate', $skill-dir)`
5. Implement `multi MAIN('read-properties', $skill-dir)`
6. Implement `multi MAIN('to-prompt', *@skill-dirs)`
7. Implement `multi MAIN(Bool :$about!)` — named Bool parameter, not positional string
8. Update `USAGE` sub (remove `build`/`init`, add `--about`)

No changes to any library modules — CLI is purely a consumer.

## Verification

```bash
just test    # all tests pass (96 existing + 16 new = 112)
just lint    # all files compile, META6.json valid
```

Manual smoke test:
```bash
d=$(mktemp -d)/test-skill && mkdir "$d"
printf '---\nname: test-skill\ndescription: A test\n---\n' > "$d/SKILL.md"
raku -Ilib bin/aigent validate "$d"                    # exit 0, no output
raku -Ilib bin/aigent read-properties "$d"             # JSON
raku -Ilib bin/aigent to-prompt "$d"                   # XML
raku -Ilib bin/aigent read-properties "$d/SKILL.md"    # smart path resolution
raku -Ilib bin/aigent --about                          # project stanza
rm -rf "$(dirname "$d")"
```

## Post-review updates

| Finding | Severity | Resolution |
|---------|----------|------------|
| PR1-1: Test count math wrong | Medium | Fixed: 96 existing + 16 new = 112 |
| PR1-2: USAGE/no-args underspecified | Medium | Added explicit USAGE section: Raku auto-handles `--help` (exit 0) and no-args (exit non-zero, stderr) |
| PR1-3: Conflicting error format drafts | Low | Removed superseded text, kept only final rule |
| PR1-4: licence vs license spelling | Low | Added explicit field mapping table (META6.json key → display label) |
| PR2-1: `multi MAIN('--about')` dead code | Medium | Changed to `Bool :$about!` named parameter |
| PR2-2: resolve-skill-dir case mismatch | Low | Aligned to exact-case (`SKILL.md`/`skill.md` only), matching `find-skill-md` |
| PR2-3: Issue #14 stale path | Low | To be fixed separately (issue body edit) |
| PR2-4: No branch strategy section | Low | Added branch strategy section |
| PR2-5: Internal deliberation prose | Low | Removed all thinking-aloud text |
