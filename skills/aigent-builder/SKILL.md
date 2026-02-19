---
name: aigent-builder
description: >
  Generates AI agent skill definitions from natural language descriptions.
  This skill creates complete SKILL.md files with valid YAML frontmatter
  and structured Markdown body following Anthropic best practices.
  Use when the user asks to "create a skill", "build a skill",
  "generate a skill", or describes a new skill they want to create.
allowed-tools: Bash, Write, Read, Glob
---
# AIgent Builder

Generates complete AI agent skill definitions from natural language purpose descriptions. Produces a valid `SKILL.md` file with YAML frontmatter and structured Markdown body following the [Anthropic agent skill best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

## When to Use

Use this skill when:
- The user asks to create, build, or generate a new agent skill
- The user describes functionality they want to package as a skill
- The user wants to scaffold a new `SKILL.md` file

## Instructions

### Step 1: Detect aigent availability

Run the following to check if the `aigent` CLI is installed:

```bash
command -v aigent
```

### Step 2a: With aigent (primary mode)

If `aigent` is on PATH, use the CLI for authoritative skill generation:

1. **Build the skill:**

   ```bash
   aigent build "<purpose>" --dir .claude/skills
   ```

   Additional options:
   - `--name <name>` — override the derived skill name
   - `--license <license>` — set a license (e.g., `MIT`)
   - `--compatibility <platform>` — set compatibility (e.g., `claude`)
   - `--allowed-tools <tools>` — set allowed tools (e.g., `Bash, Read, Write`)
   - `--no-llm` — force deterministic mode (no API key required)

   If `ANTHROPIC_API_KEY` is set, `aigent build` uses Claude to generate richer names, descriptions, and body content. Without an API key, it falls back to deterministic generation automatically.

2. **Validate the output:**

   ```bash
   aigent validate .claude/skills/<skill-name>
   ```

   Exit code 0 means valid. Any errors are printed to stderr.

3. Report the output directory path and any warnings to the user.

### Step 2b: Without aigent (fallback mode)

If `aigent` is not available, generate the skill manually using the Anthropic spec:

1. **Derive a skill name** from the user's purpose:
   - Convert to kebab-case (lowercase, hyphens between words)
   - Use gerund form for the verb (e.g., "process" becomes "processing")
   - Maximum 64 characters
   - Must not contain reserved words: `anthropic`, `claude`
   - No leading, trailing, or consecutive hyphens

2. **Write the SKILL.md** with this structure:

   ```markdown
   ---
   name: <derived-name>
   description: <third-person description>. Use when <trigger conditions>.
   ---
   # <Title Case Name>

   <Overview paragraph describing what the skill does.>

   ## When to Use

   Use this skill when:
   - <Trigger condition 1>
   - <Trigger condition 2>

   ## Instructions

   1. <Step 1>
   2. <Step 2>
   3. <Step 3>
   ```

   Rules for the description:
   - Write in third person ("This skill processes..." not "Process...")
   - Include a "Use when..." clause for auto-invocation triggers
   - Maximum 1024 characters
   - No XML-like tags (`<tag>`)

3. **Write to** `.claude/skills/<name>/SKILL.md` using the Write tool (or a user-specified directory).

4. Inform the user that validation was not run because `aigent` is not installed. Recommend installing it for authoritative validation.

### Output location

The default output directory is `.claude/skills/<name>/` (project-local skills). The user may specify an alternative directory. Both CLI mode and fallback mode use the same default.
