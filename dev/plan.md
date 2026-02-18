# Raku Skills-Ref Implementation Plan

## Context

The Python `skills-ref` library (at `agentskills/agentskills/skills-ref`) is a reference tool for validating, parsing, and generating prompts from AI agent skill definitions stored in SKILL.md files with YAML frontmatter. We are porting this to Raku as an idiomatic Raku module with the same functionality and behavior.

## Project Structure

```
raku-skills-ref/
├── META6.json                     # Raku module metadata & dependencies
├── lib/
│   └── Skills/
│       ├── Ref.rakumod            # Main module (re-exports public API)
│       └── Ref/
│           ├── Errors.rakumod     # Exception classes (X::Skills::*)
│           ├── Models.rakumod     # SkillProperties class
│           ├── Parser.rakumod     # find-skill-md, parse-frontmatter, read-properties
│           ├── Prompt.rakumod     # to-prompt (XML generation)
│           ├── Validator.rakumod  # validate, validate-metadata
│           └── Builder.rakumod    # Skill creation from natural language specs
├── bin/
│   └── skills-ref                 # CLI entry point (multi MAIN)
├── t/
│   ├── 01-errors.rakutest
│   ├── 02-models.rakutest
│   ├── 03-parser.rakutest
│   ├── 04-validator.rakutest
│   ├── 05-prompt.rakutest
│   └── 06-builder.rakutest
├── CLAUDE.md
├── LICENSE                        # (exists)
├── README.md                      # (exists, update)
└── .gitignore                     # (exists, update)
```

## Raku-Specific Design Decisions

| Python | Raku |
|--------|------|
| `@dataclass SkillProperties` | `class Skills::Ref::Models::SkillProperties` with `has` attributes |
| `SkillError / ParseError / ValidationError` | `X::Skills::Ref`, `X::Skills::Ref::Parse`, `X::Skills::Ref::Validation` |
| `click` CLI | `multi MAIN` with `USAGE` sub |
| `strictyaml` | `YAMLish` |
| `json.dumps` | `JSON::Fast` |
| `html.escape` | Custom `xml-escape` sub (only need `& < > "`) |
| `Path` | `IO::Path` |
| `pytest` / `tmp_path` | `Test` + `Test::Async`, temp dirs via `$*TMPDIR` |
| snake_case functions | kebab-case subs (Raku convention) |
| `Optional[str]` | `Str` attribute without `is required` |

---

## Milestones & Issues

### M1: Project Scaffolding
> Set up the Raku module structure, metadata, and dev tooling.

- **#1 Create META6.json** — Module metadata with name, version, auth, dependencies (YAMLish, JSON::Fast, Test::Async), provides map, and bin entry.
- **#2 Create CLAUDE.md** — Dev workflow: how to run tests (`raku -I. -e 'run <prove6 -I. -l t/>'` or `zef test .`), lint, etc.
- **#3 Update .gitignore** — Add `.precomp/`, `lib/.precomp/`, and any other Raku artifacts.
- **#4 Create stub module files** — Empty `lib/Skills/Ref.rakumod` and submodules, `bin/skills-ref` stub.
- **#23 Add GitHub Actions CI workflow** — `.github/workflows/ci.yml`: trigger on push to main and PRs, set up Raku, install deps, run tests.

### M2: Core Data Model & Errors
> Implement the exception hierarchy and the SkillProperties model.

- **#5 Implement Errors module** — `X::Skills::Ref` (base), `X::Skills::Ref::Parse` (parse failures), `X::Skills::Ref::Validation` (with `.errors` attribute holding `Str @errors`).
- **#6 Implement Models module** — `SkillProperties` class with attributes: `name` (Str, required), `description` (Str, required), `license` (Str), `compatibility` (Str), `allowed-tools` (Str), `metadata` (Hash[Str, Str]). Include `to-hash()` method (excludes undefined optional fields and empty metadata).
- **#7 Write tests for Errors and Models** — `t/01-errors.rakutest`, `t/02-models.rakutest`: construction, to-hash, exception throwing/catching.

### M3: Parser
> Parse SKILL.md frontmatter and extract skill properties.

- **#8 Implement Parser module** — Three exported subs:
  - `find-skill-md(IO::Path $dir --> IO::Path)` — locate SKILL.md (prefer uppercase)
  - `parse-frontmatter(Str $content --> List)` — return `(Hash %metadata, Str $body)`, uses YAMLish
  - `read-properties(IO::Path $dir --> SkillProperties)` — full pipeline
- **#9 Write parser tests** — `t/03-parser.rakutest`: ~15 tests covering valid frontmatter, missing/unclosed delimiters, invalid YAML, missing required fields, uppercase/lowercase file discovery, metadata with nested values, allowed-tools parsing.

### M4: Validator
> Validate skill directories and metadata against the specification.

- **#10 Implement Validator module** — Exported subs:
  - `validate-metadata(Hash %metadata, IO::Path $dir? --> List)` — returns list of error strings
  - `validate(IO::Path $dir --> List)` — full directory validation
  - Internal helpers: `validate-name`, `validate-description`, `validate-compatibility`, `validate-metadata-fields`
  - Name rules: non-empty, max 64 chars, lowercase, no leading/trailing hyphens, no consecutive hyphens, letters/digits/hyphens only, directory name match
  - i18n: Unicode NFKC normalization, support for non-ASCII lowercase
- **#11 Write validator tests** — `t/04-validator.rakutest`: ~21 tests covering valid skills, nonexistent paths, missing SKILL.md, name validation (uppercase, too long, leading hyphen, consecutive hyphens, invalid chars, directory mismatch), unexpected fields, description/compatibility length limits, i18n (Chinese, Russian, NFKC normalization).

### M5: Prompt Generation
> Generate XML prompt output from skill directories.

- **#12 Implement Prompt module** — Exported sub:
  - `to-prompt(IO::Path @dirs --> Str)` — generates `<available_skills>` XML
  - Custom `xml-escape` for `& < > "` characters
- **#13 Write prompt tests** — `t/05-prompt.rakutest`: empty list, single skill, multiple skills, special character escaping (XML injection prevention).

### M6: CLI
> Command-line interface with three subcommands.

- **#14 Implement CLI** — `bin/skills-ref` using `multi MAIN`:
  - `MAIN('validate', $skill-dir)` — validate and exit 0/1
  - `MAIN('read-properties', $skill-dir)` — output JSON (via JSON::Fast)
  - `MAIN('to-prompt', *@skill-dirs)` — output XML
  - Smart path handling: if path points to a SKILL.md file, resolve to parent dir
  - `USAGE` sub for help text
- **#15 Write CLI integration tests** — Test CLI invocations via `run` or `Proc::Async`, verify exit codes and output.

### M7: Skill Builder
> Natural language interface for creating complete skill directories from user specifications.

The Builder accepts natural language descriptions of what a skill should do, and produces a complete, valid skill directory including SKILL.md with proper frontmatter and any additional files (prompt templates, etc.). It uses the existing Models and Validator modules to ensure the generated output passes validation.

- **#16 Design Builder data model** — Define `SkillSpec` class to capture user input: purpose/goal (natural language), target name (optional, auto-derived if omitted), desired tools, compatibility notes, and any additional files to include. Define `BuildResult` to represent the output: generated `SkillProperties`, file contents map (`Hash[Str, Str]` of relative-path → content), and the output directory path.
- **#17 Implement Builder core** — `Skills::Ref::Builder` module with:
  - `build-skill(SkillSpec $spec, IO::Path $output-dir --> BuildResult)` — generates SKILL.md with valid frontmatter + markdown body from the spec, creates the output directory structure, writes all files, and validates the result using the Validator.
  - `derive-name(Str $purpose --> Str)` — derives a kebab-case skill name from a natural language description.
  - `generate-frontmatter(SkillSpec $spec --> Hash)` — builds the YAML frontmatter hash from the spec.
  - `generate-body(SkillSpec $spec --> Str)` — generates the markdown body (skill instructions/prompt content) from the spec.
  - `assess-clarity(Str $purpose --> Hash)` — evaluates whether a one-liner purpose description is sufficiently clear to generate a skill, or whether clarifying questions are needed. Returns a hash with `:clear` (Bool) and `:questions` (list of clarifying questions if not clear).
  - Post-creation validation: after writing files, runs `validate()` and reports any issues.
- **#18 Add Builder CLI subcommands** — Extend `bin/skills-ref` with:
  - `MAIN('build', Str $purpose, :$name, :$dir, :$license, :$compatibility, :$allowed-tools)` — starts from the one-liner purpose. Assesses clarity: if clear enough, generates the full skill autonomously; if ambiguous, enters a Q&A loop asking clarifying questions until the spec is sufficient, then generates. Optional flags provide overrides to skip questions. Generates full SKILL.md with frontmatter and prompt body.
  - `MAIN('init', Str $dir?)` — minimal scaffolding: creates a directory with a template SKILL.md for manual editing.
- **#19 Write Builder tests** — `t/06-builder.rakutest`: test name derivation, frontmatter generation, full build pipeline (creates valid directory), validation of generated output, edge cases (long descriptions, special characters in purpose).

### M8: Main Module & Documentation
> Wire up the public API and finalize documentation.

- **#20 Implement main module exports** — `Skills::Ref` re-exports: `find-skill-md`, `read-properties`, `parse-frontmatter`, `validate`, `validate-metadata`, `to-prompt`, `build-skill`, `SkillProperties`, `SkillSpec`, `BuildResult`, all exception classes.
- **#21 Update README.md** — Usage examples, installation, API reference, CLI docs (including builder commands).
- **#24 Add GitHub Actions release workflow** — `.github/workflows/release.yml`: trigger on tag push (`v*`), run tests, create GitHub Release, publish to Raku ecosystem (zef).

---

## Milestone Dependencies

```
M1 (Scaffolding)
 └─> M2 (Errors & Models)
      ├─> M3 (Parser)
      │    └─> M5 (Prompt)
      │         └─> M6 (CLI)
      └─> M4 (Validator)
           └─> M6 (CLI)
                └─> M7 (Builder) ─> M8 (Docs)
```

M7 (Builder) depends on M2 (Models), M4 (Validator), and M6 (CLI) because it:
- Uses SkillProperties from Models
- Validates generated output via Validator
- Extends the CLI with new subcommands

## Verification

1. **Unit tests**: `prove6 -I. -l t/` — all tests pass
2. **CLI smoke test**:
   - Create a sample skill directory with a valid SKILL.md
   - Run `raku -I. bin/skills-ref validate /path/to/skill` → exit 0
   - Run `raku -I. bin/skills-ref read-properties /path/to/skill` → valid JSON
   - Run `raku -I. bin/skills-ref to-prompt /path/to/skill` → valid XML
3. **Module install**: `zef install .` succeeds
