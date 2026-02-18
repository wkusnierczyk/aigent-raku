class AIgent::Skill::Models::SkillProperties is export {
    has Str $.name        is required;
    has Str $.description is required;
    has Str $.license;
    has Str $.compatibility;
    has Str $.allowed-tools;
    has     %.metadata;

    method to-hash(--> Hash) {
        my %h = :$!name, :$!description;
        %h<license>       = $_ with $!license;
        %h<compatibility> = $_ with $!compatibility;
        %h<allowed-tools> = $_ with $!allowed-tools;
        %h<metadata>      = %!metadata if %!metadata;
        %h;
    }
}
