package DumbBackup::RetentionPolicy;
use 5.024;
use warnings;

use POSIX            qw( strftime ceil );
use List::Util       qw( max );

use DumbBackup::Constants qw( BACKUP_RX_CAPTURES @PERIODS );

use Moo::Role;
use namespace::clean;

use experimental 'signatures';

around options_spec => sub ( $orig, @args ) {
    return (
        $orig->(@args),
        qw(
          days|keep-days|daily=i
          weeks|keep-weeks|weekly=i
          months|keep-months|monthly=i
          quarters|keep-quarters|quarterly=i
          years|keep-years|yearly=i
          )
    );
};

# default to keep is:
# enough of one periodicity to cover the enclosing periodicity
around options_defaults => sub ( $orig, @args ) {
    return (
        $orig->(@args),
        (
            days     => 7,     # a week is 7 seven days
            weeks    => 5,     # a month is 5 weeks (at most)
            months   => 3,     # a quarter is 3 months
            quarters => 4,     # a year is 4 quarters
            years    => 10,    # could be anything
        )
    );
};

my %bucket_fmt = (
    days     => '%Y-%m-%d %a',
    weeks    => '%G-%V',         # week starts on Monday
    months   => '%Y-%m',
    quarters => '%Y-%Q',         # non-standard format!
    years    => '%Y',
);

# separate dates in the corresponding buckets
sub _buckets_for (@dates) {
    my %bucket;
    for my $date ( sort @dates ) {
        my ( $y, $m, $d, $H, $M, $S ) = $date =~ BACKUP_RX_CAPTURES;
        for my $period (@PERIODS) {
            my $key =
              strftime( $bucket_fmt{$period}, $S // 0, $M // 0, $H // 0, $d,
                $m - 1, $y - 1900 );
            $key =~ s{\Q%Q\E}{ceil( $m / 3 )}e;    # %Q means quarter
            push $bucket{$period}{$key}->@*, $date;
        }
    }
    return \%bucket;
}

sub retention_hash ( $self, @backups ) {
    my $options = $self->options;
    my $bucket  = _buckets_for(@backups);
    my %keep;
    for my $period (@PERIODS) {    # for a given periodicity
        my @keep = reverse sort keys $bucket->{$period}->%*;  # grab all buckets
        splice @keep, $options->{$period} # keep the requested number of buckets
          if $options->{$period} >= 0;    # if any (negative means keep all)
        $keep{ $bucket->{$period}{$_}[-1] }++   # then keep the most recent item
          for @keep;                            # in each remaining bucket
    }
    return \%keep;
}

1;

