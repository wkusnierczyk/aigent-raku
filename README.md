# Skills::Ref

A Raku library and CLI tool for managing AI agent skill definitions. Validates, parses, and generates prompts from skill metadata stored in `SKILL.md` files with YAML frontmatter. Also provides a skill builder for creating new skills from natural language specifications.

This is a Raku port of the Python [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) reference implementation by Anthropic, extended with a skill builder module.

## Status

**Planning complete. Implementation not yet started.**

See the [development plan](dev/plan.md) for full details.

## References

- [Agent Skills organization](https://github.com/agentskills) — umbrella for agent skills tooling
- [agentskills/agentskills](https://github.com/agentskills/agentskills) — Python reference implementation (source of this port)
- [anthropics/skills](https://github.com/anthropics/skills) — Anthropic's skills repository
- [openai/skills](https://github.com/openai/skills) — OpenAI's skills repository

## Development Plan

The full implementation plan is in [`dev/plan.md`](dev/plan.md). Milestones and issues are tracked in the [Raku Skills](https://github.com/users/wkusnierczyk/projects/38) GitHub project.

### Milestones

| # | Milestone | Due | Issues |
|---|-----------|-----|--------|
| M1 | Project Scaffolding | 2026-02-19 | [#1](https://github.com/wkusnierczyk/raku-skills-ref/issues/1), [#2](https://github.com/wkusnierczyk/raku-skills-ref/issues/2), [#3](https://github.com/wkusnierczyk/raku-skills-ref/issues/3), [#4](https://github.com/wkusnierczyk/raku-skills-ref/issues/4) |
| M2 | Core Data Model & Errors | 2026-02-20 | [#5](https://github.com/wkusnierczyk/raku-skills-ref/issues/5), [#6](https://github.com/wkusnierczyk/raku-skills-ref/issues/6), [#7](https://github.com/wkusnierczyk/raku-skills-ref/issues/7) |
| M3 | Parser | 2026-02-21 | [#8](https://github.com/wkusnierczyk/raku-skills-ref/issues/8), [#9](https://github.com/wkusnierczyk/raku-skills-ref/issues/9) |
| M4 | Validator | 2026-02-22 | [#10](https://github.com/wkusnierczyk/raku-skills-ref/issues/10), [#11](https://github.com/wkusnierczyk/raku-skills-ref/issues/11) |
| M5 | Prompt Generation | 2026-02-23 | [#12](https://github.com/wkusnierczyk/raku-skills-ref/issues/12), [#13](https://github.com/wkusnierczyk/raku-skills-ref/issues/13) |
| M6 | CLI | 2026-02-24 | [#14](https://github.com/wkusnierczyk/raku-skills-ref/issues/14), [#15](https://github.com/wkusnierczyk/raku-skills-ref/issues/15) |
| M7 | Skill Builder | 2026-02-25 | [#16](https://github.com/wkusnierczyk/raku-skills-ref/issues/16), [#17](https://github.com/wkusnierczyk/raku-skills-ref/issues/17), [#18](https://github.com/wkusnierczyk/raku-skills-ref/issues/18), [#19](https://github.com/wkusnierczyk/raku-skills-ref/issues/19) |
| M8 | Main Module & Documentation | 2026-02-26 | [#20](https://github.com/wkusnierczyk/raku-skills-ref/issues/20), [#21](https://github.com/wkusnierczyk/raku-skills-ref/issues/21) |

## License

MIT
