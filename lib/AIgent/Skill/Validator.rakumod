unit module AIgent::Skill::Validator;

use AIgent::Skill::Errors;
use AIgent::Skill::Parser;

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

my constant %KNOWN-KEYS = set <name description license compatibility allowed-tools metadata>;

sub validate-name(%metadata, IO::Path $dir? --> List) {
    my @errors;

    # Check existence and type
    unless %metadata<name>:exists && %metadata<name> ~~ Str && %metadata<name>.trim.chars > 0 {
        @errors.push('Missing or empty required field: name');
        return @errors;  # Cannot validate further without a valid name
    }

    my $name = %metadata<name>.NFKC.Str;

    # Length
    if $name.chars > 64 {
        @errors.push("Name exceeds maximum length of 64 characters ({$name.chars} given)");
    }

    # Lowercase
    unless $name eq $name.lc {
        @errors.push('Name must be lowercase');
    }

    # Leading/trailing hyphen
    if $name.starts-with('-') {
        @errors.push('Name must not start with a hyphen');
    }
    if $name.ends-with('-') {
        @errors.push('Name must not end with a hyphen');
    }

    # Consecutive hyphens
    if $name.contains('--') {
        @errors.push('Name must not contain consecutive hyphens');
    }

    # Character class: letters, digits, hyphens only
    unless $name ~~ /^ [<:L> | <:N> | '-']+ $/ {
        @errors.push('Name must contain only letters, digits, and hyphens');
    }

    # Directory name match (normalize basename too for consistency)
    if $dir.defined {
        my $dir-name = $dir.basename.NFKC.Str;
        if $name ne $dir-name {
            @errors.push("Name '{$name}' does not match directory name '{$dir.basename}'");
        }
    }

    @errors;
}

sub validate-description(%metadata --> List) {
    my @errors;

    unless %metadata<description>:exists && %metadata<description> ~~ Str && %metadata<description>.trim.chars > 0 {
        @errors.push('Missing or empty required field: description');
        return @errors;
    }

    if %metadata<description>.chars > 1024 {
        @errors.push("Description exceeds maximum length of 1024 characters ({%metadata<description>.chars} given)");
    }

    @errors;
}

sub validate-compatibility(%metadata --> List) {
    my @errors;

    if %metadata<compatibility>:exists {
        unless %metadata<compatibility> ~~ Str {
            @errors.push('Compatibility must be a string');
            return @errors;
        }
        if %metadata<compatibility>.chars > 500 {
            @errors.push("Compatibility exceeds maximum length of 500 characters ({%metadata<compatibility>.chars} given)");
        }
    }

    @errors;
}

sub validate-metadata-fields(%metadata --> List) {
    my @errors;

    for %metadata.keys -> $k {
        unless $k ∈ %KNOWN-KEYS {
            @errors.push("Unknown field: $k");
        }
    }

    @errors;
}

# ---------------------------------------------------------------------------
# Exported API
# ---------------------------------------------------------------------------

sub validate-metadata(%metadata, IO::Path $dir? --> List) is export {
    my @errors;
    @errors.append: validate-name(%metadata, $dir);
    @errors.append: validate-description(%metadata);
    @errors.append: validate-compatibility(%metadata);
    @errors.append: validate-metadata-fields(%metadata);
    @errors;
}

sub validate(IO::Path $dir --> List) is export {
    my @errors;

    # Check directory exists
    unless $dir.e {
        @errors.push("Path does not exist: {$dir}");
        return @errors;
    }
    unless $dir.d {
        @errors.push("Path is not a directory: {$dir}");
        return @errors;
    }

    # Find SKILL.md
    my $path = find-skill-md($dir);
    unless $path.defined {
        @errors.push("No SKILL.md found in {$dir}");
        return @errors;
    }

    # Read and parse — catch all exceptions, convert to error strings
    my %metadata;
    try {
        my $content = $path.slurp;
        my @result = parse-frontmatter($content);
        %metadata = @result[0];
        CATCH {
            when X::AIgent::Skill::Parse {
                @errors.push(.message);
                return @errors;
            }
            default {
                @errors.push("Failed to read {$path}: {.message}");
                return @errors;
            }
        }
    }

    # Validate metadata
    @errors.append: validate-metadata(%metadata, $dir);
    @errors;
}
