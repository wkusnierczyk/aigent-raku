# Why `--no-llm` Broke My Raku CLI (and How to Fix It)

Two surprises in Raku's `MAIN` dispatch cost me hours.  This post documents
both so you don't have to rediscover them.

## The setup

I have a CLI tool with subcommands dispatched via `multi MAIN`:

```raku
multi MAIN('build', Str $purpose, Bool :$llm = True) { ... }
multi MAIN('validate', Str $dir) { ... }
```

The plan: `--no-llm` negates `$llm` to `False`, giving users a way to force
deterministic mode.  This should Just Work — Raku's pair syntax has `:!foo`
for negation, and the docs mention `--no-foo` in the CLI context.

Running it:

```
$ aigent build "Process PDF files" --no-llm
Usage:
  aigent [--llm] build <purpose>
```

Exit 2.  USAGE dump.  No match.

## Surprise 1: `--no-llm` is not `:!llm`

Let's see what Raku's CLI parser actually produces:

```raku
sub MAIN(*@pos, *%named) { say "pos: @pos.raku()"; say "named: %named.raku()" }
```

```
$ raku test.raku --no-llm build test
pos: ["build", "test"]
named: {:no-llm(Bool::True)}
```

The named parameter key is **literally `no-llm`**, not a negation of `llm`.
Raku's MAIN CLI parser does not desugar `--no-X` into `:!X`.  The `--no-`
prefix is just part of the parameter name.

This means `Bool :$llm` will **never** match `--no-llm`.  You need:

```raku
sub MAIN(Bool :$no-llm) { say $no-llm }  # matches --no-llm
```

## Surprise 2: named params must come before positionals

Even after fixing the parameter name, the dispatch still fails:

```
$ raku test.raku build "test" --no-llm
Usage:
  test.raku [--no-llm] build <purpose>
```

But reordering the arguments works:

```
$ raku test.raku --no-llm build "test"
no-llm=True
```

By default, Raku's MAIN expects **named parameters before positional
arguments**.  This is the opposite of the POSIX convention most users expect
(`command subcommand args --flags`).

The fix is a dynamic variable that reconfigures the parser:

```raku
my %*SUB-MAIN-OPTS = :named-anywhere;
```

Place it at the top of your script, before any `MAIN` subs.  Now named
parameters are accepted in any position.

## The complete fix

```raku
#!/usr/bin/env raku

my %*SUB-MAIN-OPTS = :named-anywhere;

multi MAIN('build', Str $purpose, Bool :$no-llm) {
    say "purpose=$purpose no-llm={$no-llm // False}";
}

multi MAIN('validate', Str $dir) {
    say "validate $dir";
}
```

```
$ raku tool.raku build "Process PDF files" --no-llm
purpose=Process PDF files no-llm=True

$ raku tool.raku build "Process PDF files"
purpose=Process PDF files no-llm=False

$ raku tool.raku validate ./my-skill
validate ./my-skill
```

## Summary

| Expectation | Reality |
|---|---|
| `--no-X` negates parameter `X` | `--no-X` creates parameter `no-X` |
| Named params work anywhere | Named params must precede positionals (default) |

Two lines fix both issues:

```raku
my %*SUB-MAIN-OPTS = :named-anywhere;  # POSIX-style flag ordering
# ...
multi MAIN('cmd', Bool :$no-foo) { ... }  # explicit --no-foo param
```

Neither behavior is a bug — both are documented if you know where to look.
But together they create a trap that's easy to fall into and hard to diagnose,
because the USAGE output shows the correct flag name and gives no hint about
argument ordering.
