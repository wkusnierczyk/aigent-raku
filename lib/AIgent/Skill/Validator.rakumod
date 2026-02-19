unit module AIgent::Skill::Validator;

sub validate-metadata(%metadata, IO::Path $dir? --> List) is export { ... }
sub validate(IO::Path $dir --> List) is export { ... }
