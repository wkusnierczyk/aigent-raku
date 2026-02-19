class X::AIgent::Skill is Exception is export {
    has Str $.message;
}

class X::AIgent::Skill::Parse is X::AIgent::Skill is export {}

class X::AIgent::Skill::Build is X::AIgent::Skill is export {}

class X::AIgent::Skill::Validation is X::AIgent::Skill is export {
    has Str @.errors;

    method message(--> Str) {
        @!errors.elems == 1
            ?? @!errors[0]
            !! "Validation failed:\n" ~ @!errors.map({ "  - $_" }).join("\n")
    }
}
