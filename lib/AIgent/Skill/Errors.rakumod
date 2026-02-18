class X::AIgent::Skill is Exception {
    has Str $.message;
}

class X::AIgent::Skill::Parse is X::AIgent::Skill {}

class X::AIgent::Skill::Validation is X::AIgent::Skill {
    has Str @.errors;

    method message(--> Str) {
        @!errors.elems == 1
            ?? @!errors[0]
            !! "Validation failed:\n" ~ @!errors.map({ "  - $_" }).join("\n")
    }
}
