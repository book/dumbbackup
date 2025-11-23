package DumbBackup::Sort;
use 5.024;
use warnings;

use DumbBackup::Constants qw( BACKUP_RX );

use Exporter qw( import );

our @EXPORT_OK = qw( by_date );

# a backup sort function
sub by_date {
    no strict 'refs';
    my $pkg = caller;
    my ( $A, $B ) = map $_ =~ /(${\BACKUP_RX})/, ${"$pkg\::a"}, ${"$pkg\::b"};
    return $A cmp $B;
}

1;
