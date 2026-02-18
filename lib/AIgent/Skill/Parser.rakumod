use YAMLish;
use AIgent::Skill::Errors;
use AIgent::Skill::Models;

sub find-skill-md(IO::Path $dir) is export {
    # List actual filenames on disk to handle case-insensitive filesystems
    # (macOS HFS+/APFS treat SKILL.md and skill.md as the same file)
    my @entries = $dir.dir.map(*.basename);
    return $dir.add('SKILL.md') if 'SKILL.md' ∈ @entries;
    return $dir.add('skill.md') if 'skill.md' ∈ @entries;
    Nil;
}

sub parse-frontmatter(Str $content --> List) is export {
    my @lines = $content.split("\n", :v);

    # Opening delimiter: content must start with ---
    unless $content.starts-with('---') && ($content.chars == 3 || $content.substr(3, 1) eq "\n") {
        X::AIgent::Skill::Parse.new(
            :message('SKILL.md must start with YAML frontmatter (---)')
        ).throw;
    }

    # Find closing delimiter: a line containing only "---"
    # Work with plain lines (no newline tracking needed for search)
    my @plain-lines = $content.lines;
    my $close-idx;
    for 1 ..^ @plain-lines.elems -> $i {
        if @plain-lines[$i] eq '---' {
            $close-idx = $i;
            last;
        }
    }

    unless $close-idx.defined {
        X::AIgent::Skill::Parse.new(
            :message('YAML frontmatter is not properly closed (missing closing ---)')
        ).throw;
    }

    # Extract YAML text between delimiters
    my $yaml-text = @plain-lines[1 ..^ $close-idx].join("\n");

    # Parse YAML
    my $parsed;
    try {
        $parsed = load-yaml($yaml-text);
        CATCH {
            default {
                X::AIgent::Skill::Parse.new(
                    :message("Invalid YAML in frontmatter: {.message}")
                ).throw;
            }
        }
    }

    # Must be a hash/mapping
    unless $parsed ~~ Associative {
        X::AIgent::Skill::Parse.new(
            :message('YAML frontmatter must be a mapping, not a ' ~ $parsed.^name)
        ).throw;
    }

    my %metadata = $parsed;

    # Body is everything after the closing delimiter line
    my $body = @plain-lines[$close-idx + 1 .. *].join("\n");
    # If original content ended with newline and there's body content, preserve trailing newline
    $body ~= "\n" if $body.chars > 0 && $content.ends-with("\n");

    (%metadata, $body);
}

sub read-properties(IO::Path $dir --> SkillProperties) is export {
    # Find SKILL.md
    my $path = find-skill-md($dir);
    unless $path.defined {
        X::AIgent::Skill::Parse.new(
            :message("No SKILL.md found in {$dir}")
        ).throw;
    }

    # Read and parse
    my $content = $path.slurp;
    my @result = parse-frontmatter($content);
    my %metadata = @result[0];
    my $body = @result[1];

    # Validate required fields
    my @errors;
    unless %metadata<name>:exists && %metadata<name> ~~ Str && %metadata<name>.trim.chars > 0 {
        @errors.push('Missing or empty required field: name');
    }
    unless %metadata<description>:exists && %metadata<description> ~~ Str && %metadata<description>.trim.chars > 0 {
        @errors.push('Missing or empty required field: description');
    }
    if @errors {
        X::AIgent::Skill::Validation.new(:@errors).throw;
    }

    # Extract known fields, remainder goes to metadata
    my %known-keys = set <name description license compatibility allowed-tools metadata>;
    my %extra = %metadata.grep({ .key ∉ %known-keys }).Hash;

    # Metadata comes from explicit 'metadata' key in frontmatter, merged with unknown keys
    my %meta-hash;
    %meta-hash.append(%metadata<metadata>.pairs) if %metadata<metadata>:exists && %metadata<metadata> ~~ Associative;
    %meta-hash.append(%extra.pairs) if %extra;

    SkillProperties.new(
        name         => %metadata<name>,
        description  => %metadata<description>,
        |(:license(%metadata<license>) if %metadata<license>:exists),
        |(:compatibility(%metadata<compatibility>) if %metadata<compatibility>:exists),
        |(:allowed-tools(%metadata<allowed-tools>) if %metadata<allowed-tools>:exists),
        |(:metadata(%meta-hash) if %meta-hash),
    );
}
