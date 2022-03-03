package DumbBackup::Cleanup;
use 5.024;
use warnings;

use File::Spec       qw();
use POSIX            qw( strftime ceil );
use Fcntl            qw( :flock );
use List::Util       qw( min );
use Text::ParseWords qw( shellwords );

use Moo;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

with
  'DumbBackup::Nice',
  'DumbBackup::Command',
  ;

sub options_spec {
    qw(
      store=s
      days|keep-days=i
      weeks|keep-days=i
      months|keep-months=i
      quarters|keep-quarters=i
      years|keep-years=i
      dry_run|dry-run       verbose
    );
}

# default to keep is enough of one periodicity to cover the enclosing periodicity
# - days:     a week  is 7 seven days      => keep 6
# - weeks:    a month is 5 weeks (at most) => keep 4
# - months:   a quarter is 3 months        => keep 2
# - quarters: a year is 4 quarters         => keep 3
# - years:    keep 2, the current one and the previous one
sub options_defaults {
    (
        days     => 6,
        weeks    => 4,
        months   => 2,
        quarters => 3,
        years    => 2,
    );
}

sub BUILD ( $self, $args ) {
    my $options = $self->options;
    die "--store is required\n"
        if !$options->{store};
}

my %bucket_fmt = (
    days     => '%Y-%m-%d',
    weeks    => '%Y-%W',
    months   => '%Y-%m',
    quarters => '%Y-%Q', # non-standard format!
    years    => '%Y',
);

sub _buckets_for ($date) {
    my ( $y, $m, $d ) = $date =~ /\b([0-9]{4})-([0-9]{2})-([0-9]{2})\z/;
    my %bucket;
    for my $period ( keys %bucket_fmt ) {
        my $key = strftime( $bucket_fmt{$period}, 0, 0, 0, $d, $m - 1, $y - 1900 );
        $key =~ s{\Q%Q\E}{ceil( $m / 3 )}e;    # %Q means quarter
        $bucket{$period} = $key;
    }
    return %bucket;
}

sub retention_hash ( $self, @backups ) {
    my $options = $self->options;

    # separate backups in the corresponding buckets
    my %bucket;
    for my $backup ( sort @backups ) {
	my @bucket_pairs = _buckets_for( $backup );
	while( my ($period, $key) = splice @bucket_pairs, 0, 2 ) {
            push $bucket{$period}{$key}->@*, $backup;
        }
    }

    # for each period, keep the oldest item in the selected most recent buckets
    my %keep;
    for my $period ( keys %bucket_fmt ) {
        my @keep = reverse sort keys $bucket{$period}->%*;
        splice @keep, $options->{$period};
        $keep{ $bucket{$period}{$_}[0] }++ for @keep;
    }

    return \%keep;
}

sub call ($self) {
    my $options = $self->options;

    # compute the retention hash
    my @backups = grep -d, glob "$options->{store}/????-??-??";
    my $keep    = $self->retention_hash(@backups);

    # remove everything we don't want to keep
    my @local_nice  = $self->local_nice;
    for my $bye ( grep !$keep->{$_}, @backups ) {
        my @rm = ( @local_nice, rm => '-rf', ( '-v' )x!! $options->{verbose}, $bye);
        $self->run_command(@rm);
    }

}

1;
