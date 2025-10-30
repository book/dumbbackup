package DumbBackup::Cleanup;
use 5.024;
use warnings;
use utf8;

use File::Spec       qw();
use POSIX            qw( strftime ceil );
use Fcntl            qw( :flock );
use List::Util       qw( min max );
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
      days|keep-days|daily=i
      weeks|keep-weeks|weekly=i
      months|keep-months|monthly=i
      quarters|keep-quarters|quarterly=i
      years|keep-years|yearly=i
      dry_run|dry-run       verbose
      report
      strike|strikeout|stroke
    );
}

# default to keep is enough of one periodicity to cover the enclosing periodicity
# - days:     a week  is 7 seven days      => keep 7
# - weeks:    a month is 5 weeks (at most) => keep 5
# - months:   a quarter is 3 months        => keep 3
# - quarters: a year is 4 quarters         => keep 4
# - years:    keep 10, but could be anything
sub options_defaults {
    (
        days     => 7,
        weeks    => 5,
        months   => 3,
        quarters => 4,
        years    => 10,
    );
}

sub BUILD ( $self, $args ) {
    my $options = $self->options;
    die "--store is required\n"
        if !$options->{store};
}

my @periods    = qw( days weeks months quarters years );
my %bucket_fmt = (
    days     => '%Y-%m-%d %a',
    weeks    => '%Y-%W',         # week starts on Monday
    months   => '%Y-%m',
    quarters => '%Y-%Q',         # non-standard format!
    years    => '%Y',
);

# separate dates in the corresponding buckets
sub _buckets_for (@dates) {
    my %bucket;
    for my $date ( sort @dates ) {
        my ( $y, $m, $d ) = $date =~ /\b([0-9]{4})-([0-9]{2})-([0-9]{2})\z/;
        for my $period (@periods) {
            my $key =
              strftime( $bucket_fmt{$period}, 0, 0, 0, $d, $m - 1, $y - 1900 );
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
    for my $period (@periods) {    # for a given periodicity
        my @keep = reverse sort keys $bucket->{$period}->%*;  # grab all buckets
        splice @keep, $options->{$period} # keep the requested number of buckets
          if $options->{$period} >= 0;    # if any (negative means keep all)
        $keep{ $bucket->{$period}{$_}[-1] }++   # then keep the most recent item
          for @keep;                            # in each remaining bucket
    }
    return \%keep;
}

sub retention_report ( $self, @backups ) {
    my $options = $self->options;
    my $bucket  = _buckets_for(@backups);

    # compte the bucket for each period for all backups
    my %tag;
    for my $period (@periods) {
        for my $name ( keys $bucket->{$period}->%* ) {
            $tag{$_}{$period} = $name for $bucket->{$period}{$name}->@*;
        }
    }

    # compute which backup is kept for every period bucket
    my %keep;
    for my $period (@periods) {
        my @keep = reverse sort keys $bucket->{$period}->%*;
        splice @keep, $options->{$period}
          if $options->{$period} >= 0;    # -1 means keep all
        $keep{$period}{ $bucket->{$period}{$_}[-1] }++ for @keep;
    }

    # compute the format for each column of the report
    my @headers = (
        "$options->{days} daily",
        "$options->{weeks} weekly",
        "$options->{months} monthly",
        "$options->{quarters} quarterly",
        "$options->{years} yearly",
    );
    my @fmt = map "%-${_}s",
      map max( 2 + length( $tag{ $backups[0] // '' }{ $periods[$_] } // '' ),
        length $headers[$_] ), 0 .. $#periods;

    # compute the report header
    my $report = sprintf ' ' . join( ' │ ', @fmt ) . " \n", @headers;
    $report .= '─'
      . join( '─┼─', map '─' x length( sprintf $fmt[$_], ' ' ), 0 .. $#periods )
      . "─\n";

    # compute the actual report
    for my $date ( sort @backups ) {
        $report .= ' '
          . join(
            " │ ",
            map sprintf(
                $fmt[$_],
                $tag{$date}{ $periods[$_] }
                  . ( $keep{ $periods[$_] }{$date} ? ' *' : '  ' )
            ),
            0 .. $#periods
          ) . " \n";
    }

    # strike backups to be removed with COMBINING LONG STROKE OVERLAY
    $report =~ s/^([^*y┼]*)$/$1=~s{(.)}{$1\x{336}}gr/gem
      if $options->{strike};

    return $report;
}

sub call ($self) {
    my $options = $self->options;

    # compute the list of backups
    my @backups = grep -d, glob "$options->{store}/????-??-??";

    # print a report if asked for one
    if ( $options->{report} ) {
        binmode( STDOUT, ':utf8' );
        print $self->retention_report(@backups);
        return;    # don't do anything else
    }

    # remove everything we don't want to keep
    my $keep       = $self->retention_hash(@backups);
    my @local_nice = $self->local_nice;
    for my $bye ( grep !$keep->{$_}, @backups ) {
        my @rm = ( @local_nice, rm => '-rf', ('-v')x!! $options->{verbose}, $bye );
        $self->run_command(@rm);
    }

}

1;
