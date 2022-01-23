package DumbBackup::Sort;
use 5.024;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( by_date );

# a backup sort function
sub by_date {
    no strict 'refs';
    my $pkg = caller;
    my ( $A, $B ) = map /([0-9]{4}(?:-[0-9]{2}(?:-[0-9]{2})?)?)$/, ${"$pkg\::a"}, ${"$pkg\::b"};
    return $A cmp $B;
}

1;
