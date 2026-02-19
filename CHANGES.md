# Changes

## 0.1.0

Initial release.

### Features
- SKILL.md parser with YAML frontmatter extraction
- Metadata validator with Anthropic spec compliance
  (reserved words, XML tag rejection, field constraints)
- XML prompt generator for multi-skill system prompts
- Skill builder with dual-mode architecture
  (LLM-enhanced + deterministic fallback)
- CLI tool (`aigent`) with subcommands:
  validate, read-properties, to-prompt, build, init
- Main module (`AIgent::Skill`) re-exporting full public API

### Infrastructure
- CI on Ubuntu and macOS
- Automatic retry of failed CI jobs with exponential backoff
- GitHub project board automation
- Release workflow with changelog extraction
