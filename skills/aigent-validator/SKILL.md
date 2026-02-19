---
name: aigent-validator
description: >
  Validates AI agent skill definitions against the Anthropic agent skill
  best practices specification. Checks SKILL.md frontmatter fields, name
  format, description quality, and structural requirements.
  Use when the user asks to "validate a skill", "check a skill",
  "verify SKILL.md", or wants to ensure a skill follows best practices.
allowed-tools: Bash, Read, Glob
---
# AIgent Validator

Validates AI agent skill definitions against the [Anthropic agent skill best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) specification and the reference implementation rules. Reports all validation errors with suggested fixes.

## When to Use

Use this skill when:
- The user asks to validate, check, or verify a skill definition
- The user wants to ensure a `SKILL.md` file follows best practices
- The user has just created or edited a skill and wants to confirm it is valid
- A skill build has completed and the output needs verification

## Instructions

### Step 1: Identify the target

Determine the skill directory to validate. The user may provide:
- A directory path (e.g., `.claude/skills/my-skill/`)
- A path to a `SKILL.md` file directly (resolve to its parent directory)

If not specified, look for skill directories in the current project (check `.claude/skills/` and `skills/`).

### Step 2: Detect aigent availability

Run the following to check if the `aigent` CLI is installed:

```bash
command -v aigent
```

### Step 3a: With aigent (primary mode)

If `aigent` is on PATH, use the CLI for authoritative validation:

```bash
aigent validate <skill-dir>
```

- **Exit code 0:** The skill is valid. Report success to the user.
- **Exit code 1:** Validation errors are printed to stderr. Report each error and suggest how to fix it.

Common errors and fixes:
- "Missing required field: name" — add a `name` field to the YAML frontmatter
- "Missing required field: description" — add a `description` field
- "name must match directory" — rename the directory or the `name` field to match
- "name must not contain reserved word" — remove `anthropic` or `claude` from the name
- "description must not contain XML tags" — remove any `<tag>` patterns from the description

### Step 3b: Without aigent (fallback mode)

If `aigent` is not available, validate manually by reading the `SKILL.md` file:

1. **Check file structure:**
   - File exists and is named `SKILL.md` (case-sensitive)
   - Contains YAML frontmatter between `---` delimiters

2. **Validate `name` field:**
   - Present and non-empty
   - String type
   - Lowercase letters, digits, and hyphens only (`[a-z0-9-]`)
   - Maximum 64 characters
   - No leading, trailing, or consecutive hyphens
   - Must not contain reserved words: `anthropic`, `claude`
   - Should match the directory name

3. **Validate `description` field:**
   - Present and non-empty
   - String type
   - Maximum 1024 characters
   - No XML-like tags (patterns like `<word>` or `<word/>`)

4. **Check optional fields:**
   - `license` — string if present
   - `compatibility` — string, maximum 500 characters if present
   - `allowed-tools` — string if present
   - `metadata` — hash/object if present

5. **Reject unknown fields:**
   - Only the fields listed above are permitted
   - Flag any unrecognized top-level frontmatter key

6. Report all findings to the user with specific fix suggestions.

7. Inform the user that this was a manual check. Recommend installing `aigent` for authoritative validation with full spec compliance.
