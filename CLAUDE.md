# CLAUDE.md

## Project

`Skills::Ref` — Raku AI Agent Skill Builder and Validator.
CLI tool: `aigent` (`bin/aigent`).

## Setup

```bash
just setup    # install deps + lefthook + hooks
```

## Common Commands

```bash
just test         # run tests
just lint         # syntax check + META6.json validation
just format       # whitespace scan
just format-fix   # fix trailing whitespace
just check        # format + lint + test
just install      # install module locally
```

## Versioning

Version lives exclusively in `META6.json`. Never duplicate it in source code.

```bash
just version            # print current version
just version-set 0.1.0  # set version
just bump-patch         # 0.0.1 → 0.0.2
just bump-minor         # 0.0.1 → 0.1.0
just bump-major         # 0.0.1 → 1.0.0
```

## Conventions

- kebab-case for all sub/method names
- Exception classes: `X::Skills::Ref::*` hierarchy
- Module files: `lib/Skills/Ref/*.rakumod`
- Tests: `t/*.rakutest`
- Do not commit to `main` directly — use feature branches and PRs

## Testing

```bash
just test                    # full suite
prove6 -Ilib -l t/           # alternative
raku -Ilib t/01-errors.rakutest  # single test
```
