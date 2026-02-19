# Why `zef install` Fails on Windows CI (and Why You Should Just Skip It)

Installing Raku modules on Windows in GitHub Actions hits a wall that no
amount of workarounds can fully paper over.  Here's the archaeology of six
failed attempts and the pragmatic conclusion.

## The error

```
something went wrong extracting C:\Users\RUNNER~1\AppData\Local\Temp/
.zef.1771503032.3308\1771503044.3308.4944.281607891026\
232e799dc9849c1f5e337590cd2afecbe5a569a9.tar.gz ...
[HTTP::Status] Extracting with plugin Zef::Service::Shell::tar aborted.
```

The `zef` package manager downloads modules from the Raku Ecosystem Archive
(REA) as tar.gz archives.  On Windows, `tar.exe` uses the Win32 API, which
enforces a 260-character path limit (`MAX_PATH`).  REA archive names include
SHA hashes, URL-encoded module identities, and nested temp directories.
Combined with the default `TEMP` path
(`C:\Users\RUNNER~1\AppData\Local\Temp`), the total easily exceeds 260 chars.

## The six attempts

### 1. Retry on failure

```yaml
run: zef install --deps-only . --/test || zef install --deps-only . --/test
```

**Result:** Same error.  The failure is deterministic, not transient.

### 2. Skip REA entirely (`--/rea`)

```yaml
run: zef install --deps-only . --/test --/rea
```

**Result:** `Failed to find dependencies: DateTime::Parse, Encode`.  These
modules are exclusively available on REA, not on fez.

### 3. Enable git long paths

```yaml
run: git config --system core.longpaths true
```

**Result:** Same tar error.  `core.longpaths` only affects git's own
operations, not `tar.exe` or any other Win32 program.

### 4. Shorten TEMP path

```yaml
- shell: pwsh
  run: |
    New-Item -ItemType Directory -Force -Path C:\t | Out-Null
    echo "TEMP=C:\t" >> $env:GITHUB_ENV
    echo "TMP=C:\t" >> $env:GITHUB_ENV
```

**Result:** Same tar error.  Shortening the outer path from 42 chars to 4
helps, but the problem is the *contents inside* the tar archive.  REA tars
contain deeply nested paths that overflow `MAX_PATH` regardless of the
extraction base.

### 5. Disable tar (`--/tar`)

```yaml
run: zef install --deps-only . --/test --/tar
```

**Result:** `Enabled extracting backends [git unzip path] don't understand
*.tar.gz`.  Disabling tar means zef can't extract *any* tarball, not just the
problematic ones.  The remaining backends (git, unzip, path) don't handle
tar.gz format at all.

### 6. Install REA-only deps from git, then `--/rea` for the rest

```yaml
- run: |
    zef install "https://github.com/sergot/perl6-encode.git" --/test
    zef install "https://github.com/sergot/datetime-parse.git" --/test
- run: zef install --deps-only . --/test --/rea
```

**Result:** This actually works!  But it's brittle: you must audit every
transitive dependency to find the REA-only ones, and any new dependency could
break it.

## The root cause

This isn't a `zef` bug or a CI configuration issue.  It's three things
colliding:

1. **Win32 `MAX_PATH` (260 chars)** is enforced by `tar.exe` and most Win32
   programs.  Windows 10+ has a registry key (`LongPathsEnabled`) to lift
   the limit, but applications must opt in via their manifest.  System
   `tar.exe` doesn't.

2. **REA archive naming** uses SHA hashes and URL-encoded module identities,
   producing very long filenames.  This is a known upstream issue
   ([Raku/REA#7](https://github.com/Raku/REA/issues/7)).

3. **zef's temp directory structure** adds PID-based nesting on top of the
   already-long `TEMP` path.

There's no single fix that addresses all three without fragile workarounds.

## The pragmatic solution

Drop Windows from CI.

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
```

This isn't giving up.  It's acknowledging that the problem is upstream
(REA archive naming + Windows path limits) and that CI time is better spent
on platforms where the ecosystem actually works.  The code itself is
cross-platform; it's the *dependency installation* that fails.

When REA or zef fix long-path handling, re-adding `windows-latest` to the
matrix is a one-line change.

## What I learned

- Windows `MAX_PATH` affects more than just your code.  Build tools, package
  managers, and tar implementations all inherit the limitation.
- `git config core.longpaths` is git-only.  It doesn't help tar, zef, or any
  other tool.
- `TEMP=C:\t` helps, but not enough when the tar *contents* have long paths.
- The Raku ecosystem's split between fez and REA means `--/rea` is often not
  viable: some modules only exist on REA.
- Six workarounds later, the simplest solution was removing one line from the
  CI matrix.
