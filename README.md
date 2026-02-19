<table>
  <tr>
    <td>
      <img src="https://raw.githubusercontent.com/wkusnierczyk/aigent-skills/main/graphics/aigent.png" alt="logo" width="300" />
    </td>
    <td>
      <p><strong>AIgent::Skill</strong>:
      A Raku library and CLI tool for managing AI agent skill definitions.</p>
      <p>Validates, parses, and generates prompts from skill metadata stored in <code>SKILL.md</code> files with YAML frontmatter. Also provides a skill builder for creating new skills from natural language specifications.</p>
    </td>
  </tr>
</table>

[![CI](https://github.com/wkusnierczyk/aigent-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/wkusnierczyk/aigent-skills/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Table of Contents

- [Status](#status)
- [Installation](#installation)
- [Usage](#usage)
- [SKILL.md Format](#skillmd-format)
- [Spec Compliance](#spec-compliance)
- [API Reference](#api-reference)
- [Development](#development)
- [CI/CD Workflows](#cicd-workflows)
- [Development Plan](#development-plan)
- [References](#references)
- [About and License](#about-and-license)

## Status

**M8 (Main Module & Documentation) complete.** M9 (Claude Code Plugin) in progress.

See the [development plan](dev/plan.md) for full details.

## Installation

### From source

```bash
git clone git@github.com:wkusnierczyk/aigent-skills.git
cd aigent-skills
zef install .
```

### Dependencies only (for development)

```bash
zef install --deps-only . --/test
```

Requires [Rakudo](https://rakudo.org/) (latest release) and [zef](https://github.com/ugexe/zef).

## Usage

### Library API

Import everything through the main module:

```raku
use AIgent::Skill;
```

**Validate a skill directory:**

```raku
my @errors = validate('my-skill'.IO);
if @errors {
    say "Validation errors:";
    .say for @errors;
} else {
    say "Valid.";
}
```

**Parse skill properties:**

```raku
my $props = read-properties('my-skill'.IO);
say $props.name;         # "my-skill"
say $props.description;  # "Does something useful..."
```

**Generate a system prompt from multiple skills:**

```raku
my IO::Path @dirs = ('skill-a'.IO, 'skill-b'.IO);
my $prompt = to-prompt(@dirs);
# Returns XML: <available_skills><skill>...</skill></available_skills>
```

**Build a new skill from a purpose statement:**

```raku
my $spec = SkillSpec.new(:purpose('Extract data from PDF files'));
my $result = build-skill($spec, 'output'.IO);
say $result.output-dir;       # output/extracting-data-from-pdf-files
say $result.properties.name;  # extracting-data-from-pdf-files
say $result.warnings;         # any LLM fallback warnings
```

### CLI

```
Usage: aigent <command> [options]

Commands:
  validate <dir>         Validate a skill directory
  read-properties <dir>  Read skill properties as JSON
  to-prompt <dir>...     Generate XML prompt from skill directories
  build <purpose>        Build a new skill from natural language
  init [dir]             Scaffold a new skill directory

Options:
  --about                Show project information
  --no-llm               Force deterministic mode (build only)
  --help                 Show this help message
```

**Validate:**

```bash
$ aigent validate my-skill/
# (no output = valid)

$ aigent validate bad-skill/
Missing required field: name
Missing required field: description
```

**Read properties (JSON output):**

```bash
$ aigent read-properties my-skill/
{
  "name": "my-skill",
  "description": "Does something useful..."
}
```

**Generate prompt:**

```bash
$ aigent to-prompt skill-a/ skill-b/
<available_skills>
  <skill>
    <name>skill-a</name>
    <description>...</description>
    <location>skill-a/SKILL.md</location>
  </skill>
  <skill>
    <name>skill-b</name>
    <description>...</description>
    <location>skill-b/SKILL.md</location>
  </skill>
</available_skills>
```

**Build a new skill:**

```bash
$ aigent build "Process PDF files" --dir ./skills
./skills/processing-pdf-files

$ aigent build "Process PDF files" --no-llm --dir ./skills --license MIT
./skills/processing-pdf-files
```

Build options: `--name`, `--dir` (default `.`), `--license`, `--compatibility`, `--allowed-tools`, `--no-llm`.

With `ANTHROPIC_API_KEY` set and `--no-llm` absent, the builder uses Claude to generate richer names, descriptions, and body content. Without an API key or with `--no-llm`, it falls back to deterministic generation.

**Scaffold a new skill (for manual editing):**

```bash
$ aigent init my-new-skill
my-new-skill/SKILL.md

$ cat my-new-skill/SKILL.md
---
name: my-skill
description: Describe what this skill does. Use when [trigger conditions].
---
# My Skill

Describe the skill's behavior and instructions here.
```

## SKILL.md Format

Skills are defined in `SKILL.md` files with YAML frontmatter and a Markdown body:

```markdown
---
name: extract-csv-data
description: Extract and transform data from CSV files. Use when the user needs to parse, filter, or aggregate CSV data.
license: MIT
compatibility: claude
allowed-tools: Read, Write, Bash
---
# Extract CSV Data

Parse and transform CSV files into structured data...

## When to Use

Use this skill when:
- The user asks to extract data from CSV files
- The task involves filtering or aggregating tabular data

## Instructions

1. Read the CSV file...
```

### Frontmatter fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Kebab-case identifier (e.g., `extract-csv-data`) |
| `description` | yes | What the skill does and when to use it |
| `license` | no | License identifier (e.g., `MIT`) |
| `compatibility` | no | Compatible agent platforms |
| `allowed-tools` | no | Tools the skill may use |

### Validation rules

- `name` and `description` are required and non-empty
- `name`: lowercase letters, digits, and hyphens only; max 64 chars
- `name`: must not contain [reserved words](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) (`anthropic`, `claude`)
- `description`: min 10, max 1024 chars; no XML-like tags (`<tag>`)
- Unknown frontmatter fields are rejected

## Spec Compliance

The validator is **fully compliant** with the [Anthropic agent skill best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) specification, and exceeds the reference Python implementation (`agentskills/skills-ref`) in validation coverage.

| Rule | Anthropic Spec | AIgent::Skill | Python Reference |
|------|:-:|:-:|:-:|
| Name required | ✅ | ✅ | ✅ |
| Name ≤ 64 chars | ✅ | ✅ | ✅ |
| Name: lowercase letters, numbers, hyphens | ✅ | ✅ | ✅ |
| Name: no leading/trailing/consecutive hyphens | ✅ | ✅ | ✅ |
| Name: no XML tags | ✅ | ✅ ¹ | ❌ |
| Name: no reserved words (anthropic, claude) | ✅ | ✅ | ❌ |
| Name: Unicode normalization (NFKC) | — | ✅ | ❌ |
| Name: matches directory name | — | ✅ | ✅ |
| Description required | ✅ | ✅ | ✅ |
| Description ≥ 10 chars | — | ✅ | ❌ |
| Description ≤ 1024 chars | ✅ | ✅ | ✅ |
| Description: no XML tags | ✅ | ✅ | ❌ |
| Compatibility ≤ 500 chars | ✅ | ✅ | ✅ |
| Unknown fields rejected | — | ✅ | ❌ |
| Body ≤ 500 lines warning | ✅ | ✅ ² | ❌ |

¹ Implicitly rejected: name character class (`[a-z0-9-]`) does not permit `<` or `>`.
² Checked by the builder (`check-body-warnings`), not by `validate`.

## API Reference

### Classes

| Class | Module | Description |
|-------|--------|-------------|
| `SkillProperties` | Models | Parsed skill metadata (name, description, license, ...) |
| `SkillSpec` | Builder | Input spec for skill generation (purpose, optional overrides) |
| `BuildResult` | Builder | Build output (properties, body, output-dir, warnings) |

### Functions

| Function | Module | Description |
|----------|--------|-------------|
| `find-skill-md(IO::Path $dir)` | Parser | Find `SKILL.md` in directory |
| `parse-frontmatter(Str $content)` | Parser | Split YAML frontmatter and body |
| `read-properties(IO::Path $dir)` | Parser | Parse directory into `SkillProperties` |
| `validate(IO::Path $dir)` | Validator | Validate skill directory, return errors |
| `validate-metadata(Hash %meta)` | Validator | Validate metadata hash, return errors |
| `to-prompt(IO::Path @dirs)` | Prompt | Generate XML system prompt |
| `derive-name(Str $purpose)` | Builder | Derive kebab-case name from purpose |
| `generate-description(SkillSpec $spec)` | Builder | Generate description from spec |
| `generate-body(SkillSpec $spec)` | Builder | Generate Markdown body |
| `check-body-warnings(Str $body)` | Builder | Check body for style issues |
| `assess-clarity(Str $purpose)` | Builder | Assess if purpose is clear enough |
| `build-skill(SkillSpec $spec, IO::Path $dir)` | Builder | Full build pipeline |

All builder functions accept optional `:@warnings` named parameters. All except `check-body-warnings` also accept `:$llm` (LLMClient).

### Exceptions

| Exception | Description |
|-----------|-------------|
| `X::AIgent::Skill` | Base exception |
| `X::AIgent::Skill::Parse` | Parsing failures (missing file, invalid YAML) |
| `X::AIgent::Skill::Build` | Build failures (unclear purpose, directory exists) |
| `X::AIgent::Skill::Validation` | Validation errors (has `.errors` attribute) |

## Development

### Prerequisites

- [Rakudo](https://rakudo.org/) (latest release)
- [zef](https://github.com/ugexe/zef) (module manager)
- [Just](https://github.com/casey/just) (command runner)

| Platform | Install Just |
|----------|-------------|
| macOS | `brew install just` |
| Linux (Debian/Ubuntu) | `sudo apt install just` |
| Linux (Arch) | `sudo pacman -S just` |
| Windows | `winget install Casey.Just` |
| Any (via Cargo) | `cargo install just` |

See the [Just installation docs](https://just.systems/man/en/packages.html) for more options.

### Setup

```bash
git clone git@github.com:wkusnierczyk/aigent-skills.git
cd aigent-skills
just setup
```

`just setup` installs dependencies, installs [Lefthook](https://github.com/evilmartians/lefthook) (git hooks manager), and activates the hooks.

### Common Tasks

```bash
just setup              # install deps + lefthook + hooks
just install            # install module locally (zef install .)
just test               # run test suite
just lint               # run lint-syntax + lint-meta
just format             # whitespace scan (tabs, trailing spaces)
just format-fix         # remove trailing whitespace from sources/tests
just check              # format + lint + test
```

### Versioning

Version is stored exclusively in `META6.json` — the single source of truth.

```bash
just version            # print current version
just version-set 0.1.0  # set version explicitly
just bump-patch         # 0.0.1 → 0.0.2
just bump-minor         # 0.0.1 → 0.1.0
just bump-major         # 0.0.1 → 1.0.0
```

### Git Hooks (via Lefthook)

After `just setup`, the following hooks are active:

- **pre-commit**: `just lint` — syntax check all source files
- **pre-push**: `just test` — run full test suite

## CI/CD Workflows

All workflows live in `.github/workflows/`.

### CI (`ci.yml`)

Runs on every push to `main` and on every pull request.

| Platform | Test runner |
|----------|-------------|
| Ubuntu | `just test` (prove6) |
| macOS | `just test` (prove6) |

Steps: checkout → setup Raku → cache deps → setup just → install deps → lint → test.

> **Note:** Windows is excluded due to an upstream issue with REA tar archive extraction on Windows ([Raku/REA#7](https://github.com/Raku/REA/issues/7)). The code is cross-platform; only the dependency installation fails.

### Release (`release.yml`)

Triggers on tag push (`v*`). Runs the full test suite, extracts release notes from `CHANGES.md`, and creates a GitHub Release.

Tag convention: `v0.1.0` (semver with `v` prefix).

### Rerun Failed Jobs (`rerun-failed.yml`)

Automatically retries transient CI failures (CDN outages, flaky runners) with exponential backoff. Triggers on `workflow_run: completed` when CI fails.

| Attempt | Delay | Cumulative |
|---------|-------|------------|
| 1 → 2 | 1 min | ~1 min |
| 2 → 3 | 2 min | ~3 min |
| 3 → 4 | 4 min | ~7 min |
| 4 → 5 | 8 min | ~15 min |
| 5 → 6 | 16 min | ~31 min |

After 6 attempts, the workflow gives up with a visible warning annotation.

## Development Plan

The full implementation plan is in [`dev/plan.md`](dev/plan.md). Milestones and issues are tracked in the [AIgent Skills](https://github.com/users/wkusnierczyk/projects/38) GitHub project.

### Milestones

| # | Milestone | Due | Issues |
|---|-----------|-----|--------|
| M1 | Project Scaffolding | 2026-02-19 | [#1](https://github.com/wkusnierczyk/aigent-skills/issues/1), [#2](https://github.com/wkusnierczyk/aigent-skills/issues/2), [#3](https://github.com/wkusnierczyk/aigent-skills/issues/3), [#4](https://github.com/wkusnierczyk/aigent-skills/issues/4), [#23](https://github.com/wkusnierczyk/aigent-skills/issues/23), [#27](https://github.com/wkusnierczyk/aigent-skills/issues/27), [#28](https://github.com/wkusnierczyk/aigent-skills/issues/28), [#29](https://github.com/wkusnierczyk/aigent-skills/issues/29) |
| M2 | Core Data Model & Errors | 2026-02-20 | [#33](https://github.com/wkusnierczyk/aigent-skills/issues/33), [#5](https://github.com/wkusnierczyk/aigent-skills/issues/5), [#6](https://github.com/wkusnierczyk/aigent-skills/issues/6), [#7](https://github.com/wkusnierczyk/aigent-skills/issues/7) |
| M3 | Parser | 2026-02-21 | [#8](https://github.com/wkusnierczyk/aigent-skills/issues/8), [#9](https://github.com/wkusnierczyk/aigent-skills/issues/9) |
| M4 | Validator | 2026-02-22 | [#10](https://github.com/wkusnierczyk/aigent-skills/issues/10), [#11](https://github.com/wkusnierczyk/aigent-skills/issues/11) |
| M5 | Prompt Generation | 2026-02-23 | [#12](https://github.com/wkusnierczyk/aigent-skills/issues/12), [#13](https://github.com/wkusnierczyk/aigent-skills/issues/13) |
| M6 | CLI | 2026-02-24 | [#14](https://github.com/wkusnierczyk/aigent-skills/issues/14), [#15](https://github.com/wkusnierczyk/aigent-skills/issues/15), [#26](https://github.com/wkusnierczyk/aigent-skills/issues/26) |
| M7 | Skill Builder | 2026-02-25 | [#16](https://github.com/wkusnierczyk/aigent-skills/issues/16), [#17](https://github.com/wkusnierczyk/aigent-skills/issues/17), [#18](https://github.com/wkusnierczyk/aigent-skills/issues/18), [#19](https://github.com/wkusnierczyk/aigent-skills/issues/19) |
| M8 | Main Module & Documentation | 2026-02-26 | [#20](https://github.com/wkusnierczyk/aigent-skills/issues/20), [#21](https://github.com/wkusnierczyk/aigent-skills/issues/21), [#24](https://github.com/wkusnierczyk/aigent-skills/issues/24), [#25](https://github.com/wkusnierczyk/aigent-skills/issues/25) |
| M9 | Claude Code Plugin | 2026-02-27 | [#34](https://github.com/wkusnierczyk/aigent-skills/issues/34), [#35](https://github.com/wkusnierczyk/aigent-skills/issues/35), [#38](https://github.com/wkusnierczyk/aigent-skills/issues/38), [#36](https://github.com/wkusnierczyk/aigent-skills/issues/36), [#37](https://github.com/wkusnierczyk/aigent-skills/issues/37) |

## References

| Reference | Description |
|-----------|-------------|
| [Agent Skills organization](https://github.com/agentskills) | umbrella for agent skills tooling |
| [agentskills/agentskills](https://github.com/agentskills/agentskills) | Python reference implementation |
| [anthropics/skills](https://github.com/anthropics/skills) | Anthropic's skills repository |
| [openai/skills](https://github.com/openai/skills) | OpenAI's skills repository |

## About and License

```
aigent: AI Agent Skill Builder and Validator
├─ version:    0.1.0
├─ developer:  mailto:waclaw.kusnierczyk@gmail.com
├─ source:     https://github.com/wkusnierczyk/aigent-skills
└─ licence:    MIT https://opensource.org/licenses/MIT
```

[MIT](LICENSE) — see [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)
