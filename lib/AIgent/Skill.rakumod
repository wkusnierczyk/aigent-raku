use AIgent::Skill::Errors;
use AIgent::Skill::Models;
use AIgent::Skill::Parser;
use AIgent::Skill::Validator;
use AIgent::Skill::Prompt;
use AIgent::Skill::Builder;
use JSON::Fast;

module AIgent::Skill {}

sub meta-info(--> Hash) {
    # $?DISTRIBUTION works when installed via zef; check for real metadata
    # (auto-generated -Ilib distributions lack version/description)
    if $?DISTRIBUTION.defined && $?DISTRIBUTION.meta
       && $?DISTRIBUTION.meta<version> && $?DISTRIBUTION.meta<version> ne '*' {
        return $?DISTRIBUTION.meta.hash;
    }
    # Fallback: read META6.json from source tree
    # $?FILE points to lib/AIgent/Skill.rakumod → parent(3) is repo root
    my $meta-path = $?FILE.IO.parent(3).add('META6.json');
    from-json($meta-path.slurp);
}

sub EXPORT() {
    %(
        # Exceptions
        'X::AIgent::Skill'             => X::AIgent::Skill,
        'X::AIgent::Skill::Parse'      => X::AIgent::Skill::Parse,
        'X::AIgent::Skill::Build'      => X::AIgent::Skill::Build,
        'X::AIgent::Skill::Validation' => X::AIgent::Skill::Validation,

        # Data model
        'SkillProperties' => SkillProperties,
        'SkillSpec'       => SkillSpec,
        'BuildResult'     => BuildResult,

        # Parser
        '&find-skill-md'     => &find-skill-md,
        '&parse-frontmatter' => &parse-frontmatter,
        '&read-properties'   => &read-properties,

        # Validator
        '&validate'          => &validate,
        '&validate-metadata' => &validate-metadata,

        # Prompt
        '&to-prompt' => &to-prompt,

        # Builder
        '&derive-name'          => &derive-name,
        '&generate-description' => &generate-description,
        '&generate-body'        => &generate-body,
        '&check-body-warnings'  => &check-body-warnings,
        '&assess-clarity'       => &assess-clarity,
        '&build-skill'          => &build-skill,

        # Metadata
        '&meta-info' => &meta-info,
    )
}
