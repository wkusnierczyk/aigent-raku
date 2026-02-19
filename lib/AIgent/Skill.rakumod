use AIgent::Skill::Errors;
use AIgent::Skill::Models;
use AIgent::Skill::Parser;
use AIgent::Skill::Validator;
use AIgent::Skill::Prompt;
use AIgent::Skill::Builder;

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
    )
}
