# `aigent`: Raku AI Agent Skill Builder and Validator

A Raku library and CLI tool for managing AI agent skill definitions. Validates, parses, and generates prompts from skill metadata stored in `SKILL.md` files with YAML frontmatter. Also provides a skill builder for creating new skills from natural language specifications.

This is a Raku port of the Python [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) reference implementation by Anthropic, extended with a skill builder module.

## Table of Contents

- [Status](#status)
- [References](#references)
- [Development](#development)
- [Development Plan](#development-plan)
- [About and License](#about-and-license)

## Status

**Planning complete. Implementation not yet started.**

See the [development plan](dev/plan.md) for full details.

## References

- [Agent Skills organization](https://github.com/agentskills) — umbrella for agent skills tooling
- [agentskills/agentskills](https://github.com/agentskills/agentskills) — Python reference implementation (source of this port)
- [anthropics/skills](https://github.com/anthropics/skills) — Anthropic's skills repository
- [openai/skills](https://github.com/openai/skills) — OpenAI's skills repository

## Development

### Step 1: Install Just

[Just](https://github.com/casey/just) is the project's command runner. Install it first — all other setup steps use it.

| Platform | Command |
|----------|---------|
| macOS | `brew install just` |
| Linux (Debian/Ubuntu) | `sudo apt install just` or `sudo snap install --edge --classic just` |
| Linux (Arch) | `sudo pacman -S just` |
| Windows | `winget install Casey.Just` or `scoop install just` |
| Any (via Cargo) | `cargo install just` |
| Any (prebuilt) | Download from [releases](https://github.com/casey/just/releases) |

See the [Just installation docs](https://just.systems/man/en/packages.html) for more options.

> **Why Just and not mi6?** We initially considered [App::Mi6](https://github.com/skaji/mi6) (Raku's standard module authoring tool), but it proved too limited: mi6 only provides `new`, `build`, `test`, `release`, and `version` commands. It has no support for formatting, linting, or custom targets, and no extension mechanism to add them. Since we need `lint`, `format`, `bump-*`, and other dev workflow targets, mi6 was not a viable build system for this project. We use Just instead, which provides full control over all development tasks.

### Step 2: Install Prerequisites

- [Rakudo](https://rakudo.org/) (latest release)
- [zef](https://github.com/ugexe/zef) (Raku module manager)

### Step 3: Clone and Set Up

```bash
git clone git@github.com:wkusnierczyk/raku-skills-ref.git
cd raku-skills-ref
just setup
```

`just setup` installs Raku dependencies, installs [Lefthook](https://github.com/evilmartians/lefthook) (git hooks manager), and activates the hooks.

> **Lefthook** is installed automatically by `just setup`. If you prefer to install it manually: `brew install lefthook` (macOS), `npm install -g @evilmartians/lefthook` (any platform), or download from [releases](https://github.com/evilmartians/lefthook/releases). See the [Lefthook docs](https://github.com/evilmartians/lefthook) for details.

### Git Hooks (via Lefthook)

After `just setup`, the following hooks are active:

- **pre-commit**: `just lint` — syntax check all source files
- **pre-push**: `just test` — run full test suite

### Common Tasks

```bash
just setup              # install deps + lefthook + hooks
just install            # install module locally (zef install .)
just test               # run test suite
just lint               # run lint-syntax + lint-meta
just lint-syntax        # compile-check all source files (raku -c)
just lint-meta          # validate META6.json required fields
just format             # whitespace scan (tabs, trailing spaces)
just format-fix         # remove trailing whitespace from sources/tests
just version            # print current version
just version-set 0.1.0  # set version explicitly
just bump-patch         # 0.0.1 → 0.0.2
just bump-minor         # 0.0.1 → 0.1.0
just bump-major         # 0.0.1 → 1.0.0
```

### Formatting and Linting

Raku does not have a mature equivalent of Python's `ruff`. We use:

- **`raku -c`** — syntax checking (compile without running), applied to all `.rakumod` and `.raku` files
- **META6.json validation** — checks that required fields (`name`, `version`, `provides`) are present
- **Whitespace checks** — warns about tabs and trailing whitespace; `just format-fix` removes trailing whitespace

These checks run both locally (via lefthook pre-commit hook) and in CI (GitHub Actions).

### Versioning

Version is stored exclusively in `META6.json` — the single source of truth. It is not duplicated anywhere in source code. The `--about` CLI option reads it at runtime.

```bash
just version            # print current version
just version-set 0.1.0  # set version explicitly
just bump-patch         # 0.0.1 → 0.0.2
just bump-minor         # 0.0.1 → 0.1.0
just bump-major         # 0.0.1 → 1.0.0
```

## Development Plan

The full implementation plan is in [`dev/plan.md`](dev/plan.md). Milestones and issues are tracked in the [Raku Skills](https://github.com/users/wkusnierczyk/projects/38) GitHub project.

### Milestones

| # | Milestone | Due | Issues |
|---|-----------|-----|--------|
| M1 | Project Scaffolding | 2026-02-19 | [#1](https://github.com/wkusnierczyk/raku-skills-ref/issues/1), [#2](https://github.com/wkusnierczyk/raku-skills-ref/issues/2), [#3](https://github.com/wkusnierczyk/raku-skills-ref/issues/3), [#4](https://github.com/wkusnierczyk/raku-skills-ref/issues/4), [#23](https://github.com/wkusnierczyk/raku-skills-ref/issues/23), [#27](https://github.com/wkusnierczyk/raku-skills-ref/issues/27), [#28](https://github.com/wkusnierczyk/raku-skills-ref/issues/28), [#29](https://github.com/wkusnierczyk/raku-skills-ref/issues/29) |
| M2 | Core Data Model & Errors | 2026-02-20 | [#5](https://github.com/wkusnierczyk/raku-skills-ref/issues/5), [#6](https://github.com/wkusnierczyk/raku-skills-ref/issues/6), [#7](https://github.com/wkusnierczyk/raku-skills-ref/issues/7) |
| M3 | Parser | 2026-02-21 | [#8](https://github.com/wkusnierczyk/raku-skills-ref/issues/8), [#9](https://github.com/wkusnierczyk/raku-skills-ref/issues/9) |
| M4 | Validator | 2026-02-22 | [#10](https://github.com/wkusnierczyk/raku-skills-ref/issues/10), [#11](https://github.com/wkusnierczyk/raku-skills-ref/issues/11) |
| M5 | Prompt Generation | 2026-02-23 | [#12](https://github.com/wkusnierczyk/raku-skills-ref/issues/12), [#13](https://github.com/wkusnierczyk/raku-skills-ref/issues/13) |
| M6 | CLI | 2026-02-24 | [#14](https://github.com/wkusnierczyk/raku-skills-ref/issues/14), [#15](https://github.com/wkusnierczyk/raku-skills-ref/issues/15), [#26](https://github.com/wkusnierczyk/raku-skills-ref/issues/26) |
| M7 | Skill Builder | 2026-02-25 | [#16](https://github.com/wkusnierczyk/raku-skills-ref/issues/16), [#17](https://github.com/wkusnierczyk/raku-skills-ref/issues/17), [#18](https://github.com/wkusnierczyk/raku-skills-ref/issues/18), [#19](https://github.com/wkusnierczyk/raku-skills-ref/issues/19) |
| M8 | Main Module & Documentation | 2026-02-26 | [#20](https://github.com/wkusnierczyk/raku-skills-ref/issues/20), [#21](https://github.com/wkusnierczyk/raku-skills-ref/issues/21), [#24](https://github.com/wkusnierczyk/raku-skills-ref/issues/24), [#25](https://github.com/wkusnierczyk/raku-skills-ref/issues/25) |

## About and License

```
aigent: Raku AI Agent Skill Builder and Validator
├─ version:    0.0.1
├─ developer:  mailto:waclaw.kusnierczyk@gmail.com
├─ source:     https://github.com/wkusnierczyk/raku-skills-ref
└─ licence:    MIT https://opensource.org/licenses/MIT
```

[MIT](LICENSE) — see [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)
