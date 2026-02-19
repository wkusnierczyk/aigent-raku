unit module AIgent::Skill::Builder;

use AIgent::Skill::Errors;
use AIgent::Skill::Models;

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
# Exported stubs — compile but throw X::StubCode at runtime
# ---------------------------------------------------------------------------

sub derive-name(Str $purpose, :$llm --> Str) is export { !!! }
sub generate-description(SkillSpec $spec, :$llm --> Str) is export { !!! }
sub generate-body(SkillSpec $spec, :$llm --> Str) is export { !!! }
sub check-body-warnings(Str $body --> List) is export { !!! }
sub assess-clarity(Str $purpose, :$llm --> Hash) is export { !!! }
sub build-skill(SkillSpec $spec, IO::Path $output-dir, :$llm --> BuildResult) is export { !!! }
