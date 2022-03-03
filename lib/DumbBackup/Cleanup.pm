package DumbBackup::Cleanup;
use 5.024;
use warnings;

use File::Spec       qw();
use POSIX            qw( strftime );
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
      years|keep-years=i
      dry_run|dry-run       verbose
    );
}

# default to keep is half of the larger period, rounded up
# - days:   a week  is 7 seven days      => keep 4
# - weeks:  a month is 5 weeks (at most) => keep 3
# - months: a year  is 12 months         => keep 6
# - years:  keep 2, the current one and the previous one
sub options_defaults {
    (
        days   => 4,
        weeks  => 3,
        months => 6,
        years  => 2,
    );
}

sub BUILD ( $self, $args ) {
    my $options = $self->options;
    die "--store is required\n"
        if !$options->{store};
}

my %bucket_fmt = (
    days   => '%Y-%m-%d',
    weeks  => '%Y-%W',
    months => '%Y-%m',
    years  => '%Y',
);

sub retention_hash ( $self, @backups ) {
    my $options = $self->options;

    # separate backups in the corresponding buckets
    my %bucket;
    for my $backup ( sort @backups ) {
        my ( $y, $m, $d ) = $backup =~ /\b([0-9]{4})-([0-9]{2})-([0-9]{2})\z/;
        for my $period ( keys %bucket_fmt ) {
            my $key = strftime( $bucket_fmt{$period}, 0, 0, 0, $d, $m - 1, $y - 1900 );
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
    my $today   = strftime "%Y-%m-%d", localtime;
    my $dest    = "$options->{store}/$today";

    # never delete today's backup
    my @backups = grep $_ ne $dest, grep -d, glob "$options->{store}/????-??-??";

    # compute the retention hash
    my $keep = $self->retention_hash(@backups);

    # remove everything we don't want to keep
    my @local_nice  = $self->local_nice;
    for my $bye ( grep !$keep->{$_}, @backups ) {
        my @rm = ( @local_nice, rm => '-rf', ( '-v' )x!! $options->{verbose}, $bye);
        $self->run_command(@rm);
    }

}

1;
