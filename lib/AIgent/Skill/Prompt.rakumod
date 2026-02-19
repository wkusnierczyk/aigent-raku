unit module AIgent::Skill::Prompt;

use AIgent::Skill::Errors;
use AIgent::Skill::Parser;

# ---------------------------------------------------------------------------
# xml-escape — escape XML special characters
# ---------------------------------------------------------------------------
# Ampersand must be first to avoid double-escaping.

sub xml-escape(Str $s --> Str) is export {
    $s.subst('&', '&amp;', :g)
      .subst('<', '&lt;',  :g)
      .subst('>', '&gt;',  :g)
      .subst('"', '&quot;', :g)
}

# ---------------------------------------------------------------------------
# to-prompt — generate <available_skills> XML from skill directories
# ---------------------------------------------------------------------------
# Exceptions from find-skill-md / read-properties propagate to the caller.

sub to-prompt(IO::Path @dirs --> Str) is export {
    my @skills;

    for @dirs -> $dir {
        my $path = find-skill-md($dir);
        unless $path.defined {
            X::AIgent::Skill::Parse.new(
                :message("No SKILL.md found in {$dir}")
            ).throw;
        }
        my $props = read-properties($dir);

        @skills.push: qq:to/SKILL/.chomp;
          <skill>
            <name>{xml-escape($props.name)}</name>
            <description>{xml-escape($props.description)}</description>
            <location>{xml-escape($path.Str)}</location>
          </skill>
        SKILL
    }

    my $inner = @skills ?? "\n" ~ @skills.join("\n") ~ "\n" !! "\n";
    "<available_skills>" ~ $inner ~ "</available_skills>";
}
