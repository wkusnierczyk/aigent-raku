# CLAUDE.md

## Project

`AIgent::Skill` — Raku AI Agent Skill Builder and Validator.
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
- Exception classes: `X::AIgent::Skill::*` hierarchy
- Module files: `lib/AIgent/Skill/*.rakumod`
- Tests: `t/*.rakutest`
- Do not commit to `main` directly — use feature branches and PRs

## Testing

```bash
just test                    # full suite
prove6 -Ilib -l t/           # alternative
raku -Ilib t/01-errors.rakutest  # single test
```

## Pull Requests

PRs must be assigned to `wkusnierczyk`, labeled, added to the [Raku Skills](https://github.com/users/wkusnierczyk/projects/38) project, and given a milestone.

Use this body format:

```markdown
## Summary
- Description of first change
  Closes #N
- Description of second change
  Closes #N
  Closes #M

## Test plan
- [ ] Check item 1
- [ ] Check item 2

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Rules:
- Description on the first line, issue refs on subsequent lines (two trailing spaces for line break)
- Each issue on its own line — `Closes #N` for auto-closing on merge
- Never combine multiple issues on one line

## CI: Rerun Failed Jobs with Exponential Backoff

`.github/workflows/rerun-failed.yml` automatically retries transient CI failures (CDN outages, flaky runners, etc.) with exponential backoff.

### Design

- Triggers on `workflow_run: completed` when the CI workflow fails
- Uses `actions/github-script` to call `reRunWorkflowFailedJobs` after a delay
- Each retry fires a new `workflow_run` event, so the same workflow handles all retries — no loop, no recursion

### Backoff schedule

| Attempt | Delay before retry | Cumulative wait |
|---------|-------------------|-----------------|
| 1 → 2 | 1 min | ~1 min |
| 2 → 3 | 2 min | ~3 min |
| 3 → 4 | 4 min | ~7 min |
| 4 → 5 | 8 min | ~15 min |
| 5 → 6 | 16 min | ~31 min |

Formula: `delay = 2^(attempt-1) * 60` seconds.

### Parameters

- `maxAttempts`: 6 (5 retries). Increase if longer outages are expected.
- Base delay: 60 seconds. Adjust the multiplier in `Math.pow(2, attempt - 1) * 60` to change the scale.

### Give-up behavior

When `attempt >= maxAttempts`, the workflow logs a `core.warning()` and exits. This produces a yellow annotation on the workflow run, making it visually obvious that retries were exhausted (unlike `console.log` which exits silently green).

### Implementation

```yaml
steps:
  - name: Rerun failed jobs with backoff
    uses: actions/github-script@v7
    with:
      script: |
        const run_id = context.payload.workflow_run.id;
        const attempt = context.payload.workflow_run.run_attempt;
        const maxAttempts = 6;

        if (attempt >= maxAttempts) {
          core.warning(`Run ${run_id} at attempt ${attempt} — giving up after ${maxAttempts} attempts.`);
          return;
        }

        const delaySec = Math.pow(2, attempt - 1) * 60;
        const delayMin = delaySec / 60;
        console.log(`Run ${run_id} failed on attempt ${attempt}. Waiting ${delayMin}m before retry...`);

        await new Promise(resolve => setTimeout(resolve, delaySec * 1000));

        console.log(`Rerunning failed jobs for run ${run_id} (attempt ${attempt + 1} of ${maxAttempts})...`);
        await github.rest.actions.reRunWorkflowFailedJobs({
          owner: context.repo.owner,
          repo: context.repo.repo,
          run_id: run_id,
        });
```

### Required permissions

```yaml
permissions:
  actions: write
```
