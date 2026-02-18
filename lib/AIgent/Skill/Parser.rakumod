use AIgent::Skill::Errors;
use AIgent::Skill::Models;

sub find-skill-md(IO::Path $dir) is export {
    ...
}

sub parse-frontmatter(Str $content --> List) is export {
    ...
}

sub read-properties(IO::Path $dir --> SkillProperties) is export {
    ...
}
