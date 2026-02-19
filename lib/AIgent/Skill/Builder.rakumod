unit module AIgent::Skill::Builder;

use YAMLish;
use JSON::Fast;
use HTTP::UserAgent;
use AIgent::Skill::Errors;
use AIgent::Skill::Models;
use AIgent::Skill::Validator;

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

class SkillSpec is export {
    has Str $.purpose    is required;
    has Str $.name;
    has Str $.allowed-tools;
    has Str $.compatibility;
    has Str $.license;
}

class BuildResult is export {
    has SkillProperties $.properties is required;
    has Str             $.body       is required;
    has IO::Path        $.output-dir is required;
    has Str             @.warnings;
}

# ---------------------------------------------------------------------------
# LLM Client (internal, not exported)
# ---------------------------------------------------------------------------

class LLMClient {
    has Str $.api-key  is required;
    has Str $.model    = %*ENV<AIGENT_MODEL> // 'claude-sonnet-4-20250514';

    method generate(Str $system-prompt, Str $user-prompt --> Str) {
        my $ua = HTTP::UserAgent.new(:timeout(30));

        my %body = %(
            model    => $!model,
            max_tokens => 1024,
            system   => $system-prompt,
            messages => [
                %( role => 'user', content => $user-prompt ),
            ],
        );

        my $response;
        try {
            $response = $ua.post(
                'https://api.anthropic.com/v1/messages',
                'Content-Type'      => 'application/json',
                'x-api-key'         => $!api-key,
                'anthropic-version'  => '2023-06-01',
                to-json(%body),
            );
            CATCH {
                default {
                    X::AIgent::Skill::Build.new(
                        :message("LLM API request failed: {.message}")
                    ).throw;
                }
            }
        }

        unless $response.is-success {
            X::AIgent::Skill::Build.new(
                :message("LLM API returned {$response.code}: {$response.content}")
            ).throw;
        }

        my %result = from-json($response.content);
        my $text = %result<content>[0]<text> // '';
        $text.trim;
    }
}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

my constant @STOP-WORDS = <a an the and or for from to with in of that this
                           is are be can will should do does did has have>;

my constant @AMBIGUOUS-TERMS = <stuff things handle it something do make>;

# Never double these consonants
my constant @NO-DOUBLE = <w x y>;

# ---------------------------------------------------------------------------
# Gerund conversion
# ---------------------------------------------------------------------------

sub to-gerund(Str $verb --> Str) {
    my $v = $verb.lc;

    # Already ends in -ing
    return $v if $v.ends-with('ing') && $v.chars > 4;

    # Ends in "ie" → "ying"
    return $v.substr(0, *-2) ~ 'ying' if $v.ends-with('ie');

    # Ends in silent "e" (but not "ee", "ye", "oe")
    if $v.ends-with('e') && $v.chars > 2 {
        my $pre = $v.substr(*-2, 1);
        unless $pre eq 'e' | 'y' | 'o' {
            return $v.substr(0, *-1) ~ 'ing';
        }
    }

    # Monosyllabic CVC: single vowel + single consonant → double consonant
    # Only for monosyllabic words; exclude w, x, y from doubling
    if $v.chars >= 2 && $v.chars <= 5 {
        my $last = $v.substr(*-1);
        if $last ~~ /<[bcdfghjklmnpqrstvz]>/ && $last !(elem) @NO-DOUBLE {
            my $rest = $v.substr(0, *-1);
            # Check it's a simple CVC pattern: has exactly one vowel cluster
            my @vowel-groups = $rest.comb(/<[aeiou]>+/);
            if @vowel-groups.elems == 1 {
                return $v ~ $last ~ 'ing';
            }
        }
    }

    # Default
    $v ~ 'ing';
}

# ---------------------------------------------------------------------------
# Exported functions
# ---------------------------------------------------------------------------

sub derive-name(Str $purpose, :$llm --> Str) is export {
    # LLM mode
    if $llm.defined {
        try {
            my $result = $llm.generate(
                "You derive kebab-case skill names from natural language descriptions.",
                "Given this purpose, derive a kebab-case skill name in gerund form (e.g., 'processing-pdfs'). Return only the name, nothing else.\n\nPurpose: $purpose"
            );
            my $name = $result.trim.lc;
            # Validate LLM result
            if $name.chars > 0 && $name.chars <= 64
                && $name ~~ /^ [<[a..z0..9]> | '-']+ $/
                && !$name.contains('anthropic')
                && !$name.contains('claude') {
                return $name;
            }
            CATCH {
                when X::AIgent::Skill::Build { }  # fall through to deterministic
            }
        }
    }

    # Deterministic mode
    my $text = $purpose.lc;
    $text = $text.subst(/<-[a..z \s 0..9]>/, '', :g);  # strip punctuation
    my @words = $text.words.grep({ $_ !(elem) @STOP-WORDS });

    return 'new-skill' unless @words;

    my $verb = @words.shift;
    my $gerund = to-gerund($verb);

    my @object = @words.head(2);  # take first 1-2 remaining words
    my $name = ($gerund, |@object).join('-');

    # Truncate to 64 chars, trim trailing hyphens
    $name = $name.substr(0, 64) if $name.chars > 64;
    $name = $name.subst(/'-'+$/, '');

    $name;
}

sub generate-description(SkillSpec $spec, :$llm --> Str) is export {
    # LLM mode
    if $llm.defined {
        try {
            my $result = $llm.generate(
                "You write skill descriptions following Anthropic best practices: third person, include what the skill does and when to use it.",
                "Write a skill description for this purpose. Use third person. Include what the skill does and when to use it ('Use when...'). Keep under 1024 characters. Return only the description.\n\nPurpose: {$spec.purpose}"
            );
            return $result.substr(0, 1024) if $result.chars > 0;
            CATCH {
                when X::AIgent::Skill::Build { }  # fall through
            }
        }
    }

    # Deterministic mode
    my $text = $spec.purpose;

    # Capitalize first letter for third-person form
    $text = $text.substr(0, 1).uc ~ $text.substr(1) if $text.chars > 0;

    # Ensure ends with period before appending "Use when"
    $text = $text.trim;
    $text ~= '.' unless $text.ends-with('.');

    # Append "Use when" clause if not already present
    unless $text.contains('Use when') || $text.contains('use when') {
        # Extract key terms from purpose
        my @words = $spec.purpose.lc.words.grep({ $_ !(elem) @STOP-WORDS });
        my $terms = @words.head(3).join(', ');
        $text ~= " Use when the user needs to work with {$terms}.";
    }

    # Cap at 1024
    $text.substr(0, 1024);
}

sub generate-body(SkillSpec $spec, :$llm --> Str) is export {
    # LLM mode
    if $llm.defined {
        try {
            my $result = $llm.generate(
                "You generate SKILL.md body content following Anthropic best practices.",
                "Generate a SKILL.md body for this skill. Include sections: overview paragraph, '## When to Use' with bullet triggers, '## Instructions' with numbered steps. Write in third person. Be specific to the purpose. Do not include YAML frontmatter.\n\nPurpose: {$spec.purpose}"
            );
            return $result if $result.chars > 0;
            CATCH {
                when X::AIgent::Skill::Build { }  # fall through
            }
        }
    }

    # Deterministic mode — fill template from spec
    my $name = $spec.name // derive-name($spec.purpose);
    my $title = $name.split('-').map(*.tc).join(' ');

    my @keywords = $spec.purpose.lc.words.grep({ $_ !(elem) @STOP-WORDS });
    my $keyword-str = @keywords.head(3).join(', ');

    qq:to/BODY/.chomp;
    # {$title}

    {$spec.purpose.substr(0, 1).uc ~ $spec.purpose.substr(1).trim}. This skill handles the complete workflow and returns structured results.

    ## When to Use

    Use this skill when:
    - The user asks about {$keyword-str}
    - The task involves {$spec.purpose.lc}

    ## Instructions

    When activated, follow these steps:
    1. Parse and validate the user's request
    2. {$spec.purpose.substr(0, 1).uc ~ $spec.purpose.substr(1)}
    3. Validate outputs and handle errors gracefully
    4. Return results in a clear, structured format
    BODY
}

sub check-body-warnings(Str $body --> List) is export {
    my @warnings;
    my $lines = $body.lines.elems;
    if $lines > 500 {
        @warnings.push("SKILL.md body exceeds 500 lines ({$lines} lines); consider splitting into separate files");
    }
    @warnings;
}

sub assess-clarity(Str $purpose, :$llm --> Hash) is export {
    # LLM mode
    if $llm.defined {
        try {
            my $result = $llm.generate(
                "You evaluate whether purpose descriptions are clear enough to generate AI agent skills.",
                "Evaluate whether this purpose is clear enough to generate an AI agent skill. If unclear, provide 1-3 specific clarifying questions. Respond as JSON: \{\"clear\": true/false, \"questions\": [...]}\n\nPurpose: $purpose"
            );
            my %parsed = from-json($result);
            return %parsed if %parsed<clear>:exists;
            CATCH {
                when X::AIgent::Skill::Build { }  # fall through
                default { }  # JSON parse failure, fall through
            }
        }
    }

    # Deterministic mode
    my @questions;

    # Too short
    if $purpose.chars < 10 {
        @questions.push('The purpose is too short to determine intent. What specific task should this skill perform?');
        return %( clear => False, questions => @questions );
    }

    # No verb detected (check against common action words)
    my @words = $purpose.lc.words.grep({ $_ !(elem) @STOP-WORDS });
    unless @words {
        @questions.push('Could not identify the action — what should this skill do?');
        return %( clear => False, questions => @questions );
    }

    # All ambiguous terms
    if @words.grep({ $_ !(elem) @AMBIGUOUS-TERMS }).elems == 0 {
        @questions.push('The description is too vague. What specific action should this skill perform?');
        @questions.push('What kind of input will this skill work with?');
        return %( clear => False, questions => @questions );
    }

    %( clear => True, questions => @questions );
}

sub build-skill(SkillSpec $spec, IO::Path $output-dir, :$llm --> BuildResult) is export {
    my @warnings;

    # Determine name
    my $name = $spec.name // derive-name($spec.purpose, :$llm);

    # Check for LLM fallback warnings
    my $effective-llm = $llm;
    # (Individual function calls handle their own fallback internally)

    # Generate content
    my $description = generate-description($spec, :$llm);
    my $body        = generate-body($spec, :$llm);

    # Create skill directory
    my $skill-dir = $output-dir.add($name);
    if $skill-dir.e {
        X::AIgent::Skill::Build.new(
            :message("Directory already exists: {$skill-dir}")
        ).throw;
    }
    $skill-dir.mkdir;

    # Assemble SKILL.md
    my %frontmatter = %(
        name        => $name,
        description => $description,
    );
    %frontmatter<license>       = $_ with $spec.license;
    %frontmatter<compatibility> = $_ with $spec.compatibility;
    %frontmatter<allowed-tools> = $_ with $spec.allowed-tools;

    # Build YAML manually — save-yaml quotes keys which YAMLish can't re-parse
    my @yaml-lines;
    @yaml-lines.push("name: {$name}");
    # Use single-quoted YAML for description to handle special characters
    my $esc-desc = $description.subst("'", "''", :g);
    @yaml-lines.push("description: '{$esc-desc}'");
    @yaml-lines.push("license: {$_}") with %frontmatter<license>;
    @yaml-lines.push("compatibility: {$_}") with %frontmatter<compatibility>;
    @yaml-lines.push("allowed-tools: {$_}") with %frontmatter<allowed-tools>;
    my $content = "---\n" ~ @yaml-lines.join("\n") ~ "\n---\n{$body}\n";

    # Write SKILL.md
    $skill-dir.add('SKILL.md').spurt($content);

    # Validate
    my @errors = validate($skill-dir);
    if @errors {
        X::AIgent::Skill::Validation.new(:@errors).throw;
    }

    # Check body warnings
    @warnings.append: check-body-warnings($body);

    # Build properties
    my $properties = SkillProperties.new(
        :$name,
        :$description,
        |(:license($spec.license)       if $spec.license.defined),
        |(:compatibility($spec.compatibility) if $spec.compatibility.defined),
        |(:allowed-tools($spec.allowed-tools) if $spec.allowed-tools.defined),
    );

    BuildResult.new(
        :$properties,
        :$body,
        :output-dir($skill-dir),
        :@warnings,
    );
}
