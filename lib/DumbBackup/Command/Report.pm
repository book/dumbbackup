package DumbBackup::Command::Report;
use 5.024;
use warnings;
use utf8;

use File::Basename   qw( basename );
use List::Util       qw( max );
use DumbBackup::Constants qw( BACKUP_RX @PERIODS );

use Moo;
use namespace::clean;

use experimental 'signatures';

with
  'RYO::Command',
  'DumbBackup::RetentionPolicy',
  ;

sub options_spec {
    qw(
      strike|strikeout|stroke
      show_backups|show-backups|backups!
    );
}

sub options_defaults { }

sub retention_report ( $self, $store, @backups ) {
    my $options = $self->options;
    my $bucket  = _buckets_for(@backups);

    # compte the bucket for each period for all backups
    my %tag;
    for my $period (@PERIODS) {
        for my $name ( keys $bucket->{$period}->%* ) {
            $tag{$_}{$period} = $name for $bucket->{$period}{$name}->@*;
        }
    }

    # compute which backup is kept for every period bucket
    my %keep;
    for my $period (@PERIODS) {
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
      map max( 2 + length( $tag{ $backups[0] // '' }{ $PERIODS[$_] } // '' ),
        length $headers[$_] ),
      0 .. $#PERIODS;

    # shall we show the "backup" column?
    my $show_backups = !!$options->{show_backups};
    if ($show_backups) {
        unshift @headers, 'backup';
        unshift @fmt,     sprintf '%%-%ds',
          max( map length basename($_), @backups );
    }

    # compute the report header
    my $report = '─'
      . join( '─┬─', map '─' x length( sprintf $_, ' ' ), @fmt )
      . "─\n";
    $report .= sprintf ' ' . join( ' │ ', @fmt ) . " \n", @headers;
    $report .= '─'
      . join( '─┼─', map '─' x length( sprintf $_, ' ' ), @fmt )
      . "─\n";

    # compute the actual report
    my $keeping = 0;
    for my $date ( sort @backups ) {
        my $line .= ' '
          . join(
            " │ ",
            ( sprintf( $fmt[0], basename($date) ) ) x $show_backups,
            map sprintf(
                $fmt[ $_ + $show_backups ],
                $tag{$date}{ $PERIODS[$_] }
                  . ( $keep{ $PERIODS[$_] }{$date} ? ' *' : '  ' )
            ),
            0 .. $#PERIODS
          ) . " \n";
        $keeping++ if $line =~ /\*/;
        $report .= $line;
    }

    # strike backups to be removed with COMBINING LONG STROKE OVERLAY
    $report =~ s/^([^*y┼┬]*)$/$1=~s{(.)}{$1\x{336}}gr/gem
      if $options->{strike};

    return sprintf " $store (%d backup%s, keep %s)\n$report",
      scalar @backups, @backups > 1 ? 's' : '',
      $keeping == @backups ? $keeping == 1 ? 'it' : 'all' : $keeping;
}

sub summary_report ( $self, @stores ) {
    my @store_backups =
      sort {    # sort by:
        $a->[1] cmp $b->[1]           # first backup
          || $a->[-1] cmp $b->[-1]    # last backup
          || $a->[0] cmp $b->[0]      # hostname
      }
      grep @$_ > 1,                   # only show stores with at least 1 backup
      map [ map basename($_),         # just keep the store and backup names
        $_,                           # hostname / store
        sort grep -d, grep $_ =~ BACKUP_RX, glob "$_/*" ],
      grep -d, @stores;
    return unless @store_backups;

    # header
    my $first_cell = max map length, 'host', map $_->[0], @store_backups;
    my $fmt        = " %${first_cell}s │ %-19s │ %-19s │";
    my $summary    = sprintf "$fmt count │ keep \n", qw( host first last );
    $summary .= join( '┼',
        '─' x ( $first_cell + 2 ),
        '─' x 21, '─' x 21, '─' x 7, '─' x 6 )
      . "\n";

    # store summaries
    for my $store_backups (@store_backups) {
        my ( $store, @backups ) = @$store_backups;
        $summary .= sprintf "$fmt %5d │ %4d \n", $store,
          basename( $backups[0] ), basename( $backups[-1] ),
          scalar @backups, scalar keys $self->retention_hash(@backups)->%*;
    }
    return $summary;
}

sub call ( $self ) {
    my $options = $self->options;
    my @stores  = $self->arguments->@*;

    binmode( STDOUT, ':utf8' );
    if ( $self->command eq 'summary' ) {
        @stores = glob '*' unless @stores;    # default to current dir
        say $self->summary_report(@stores);
    }
    else {
        for my $store (@stores) {
            my @backups = grep -d, grep $_ =~ BACKUP_RX, glob "$store/*";
            say $self->retention_report( $store, @backups )
              if @backups;
        }
    }

    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME

dumbbackup report - Show report on stored backups, according to the retention policy

=head1 SYNOPSIS

  dumbbackup report [options] DIR...

Aliases: C<report>, C<summary>.

=head2 OPTIONS

=head3 Reporting options

    --strike               strike out the backups to be deleted from the report
    --show-backups         show an additional column with the actual backup name

=head3 Retention policy options

These options help define the retention policy for the report:

    --keep-days <n>        keep <n> daily backups
    --keep-weeks <n>       keep <n> weekly backups
    --keep-months <n>      keep <n> monthly backups
    --keep-quarters <n>    keep <n> quarterly backups
    --keep-years <n>       keep <n> yearly backups

All options above accept the corresponding aliases.
E.g., I<--days> and I<--daily> are valid aliases for I<--keep-days>.

=head1 DESCRIPTION

=head2 Report

B<dumbbackup report> prints a retention report on all the backups found
in the given stores.

The table header summarizes the retention policy.

     host (17 backups, keep 15)
    ──────────────────┬───────────┬───────────┬─────────────┬───────────
     7 daily          │ 5 weekly  │ 3 monthly │ 4 quarterly │ 10 yearly 
    ──────────────────┼───────────┼───────────┼─────────────┼───────────
     2024-03-31 Sun   │ 2024-13   │ 2024-03   │ 2024-1 *    │ 2024      
     2024-06-30 Sun   │ 2024-26   │ 2024-06   │ 2024-2 *    │ 2024      
     2024-09-30 Mon   │ 2024-40   │ 2024-09   │ 2024-3 *    │ 2024      
     2024-10-31 Thu   │ 2024-44   │ 2024-10 * │ 2024-4      │ 2024      
     2024-11-30 Sat   │ 2024-48   │ 2024-11 * │ 2024-4      │ 2024      
     2024-12-08 Sun   │ 2024-49 * │ 2024-12   │ 2024-4      │ 2024      
     2024-12-15 Sun   │ 2024-50 * │ 2024-12   │ 2024-4      │ 2024      
     2024-12-22 Sun   │ 2024-51 * │ 2024-12   │ 2024-4      │ 2024      
     2024-12-24 Thu   │ 2024-52   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-25 Wed * │ 2024-52   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-26 Thu * │ 2024-52   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-27 Fri * │ 2024-52   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-28 Sat * │ 2024-52   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-29 Sun * │ 2024-52 * │ 2024-12   │ 2024-4      │ 2024      
     2024-12-30 Mon   │ 2024-53   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-30 Mon * │ 2024-53   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-31 Tue * │ 2024-53 * │ 2024-12 * │ 2024-4 *    │ 2024 *    

The backups to be I<kept> are marked with a C<*> in the generated table.
Anything not marked as retained is going to be deleted when the
B<dumbbackup cleanup> command is run.

The backup directories are of the form C<YYYY-MM-DD_hh-mm-ss>. When the
"backup" column is not shown (the default), the same day can show up
multiple times in the "daily" column, if multiple backups exist for
that day.

=head2 Summary

When called as B<dumbbackup summary>, the command prints a summary of
all the stores passed on the command-line:

        host │ first               │ last                │ count │ keep 
    ─────────┼─────────────────────┼─────────────────────┼───────┼──────
      thwack │ 2019-10-11          │ 2022-01-14          │    34 │   15 
       zlonk │ 2024-01-01          │ 2025-10-29_10-12-00 │    20 │   14 
     sploosh │ 2024-06-30          │ 2025-03-09          │    16 │   16 
       kapow │ 2024-12-07          │ 2025-01-09          │    14 │   11 
       rakkk │ 2025-11-22_08-59-34 │ 2025-11-23_17-12-04 │     5 │    2 

The "keep" column shows how many backups would remain after running
B<dumbbackup cleanup>.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
