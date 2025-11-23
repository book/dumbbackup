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
    qw( strike|strikeout|stroke );
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
        "backup",
        "$options->{days} daily",
        "$options->{weeks} weekly",
        "$options->{months} monthly",
        "$options->{quarters} quarterly",
        "$options->{years} yearly",
    );
    my @fmt = map "%-${_}s", max( map length basename($_), @backups ),
      map max( 2 + length( $tag{ $backups[0] // '' }{ $PERIODS[$_] } // '' ),
        length $headers[ $_ + 1 ] ),
      0 .. $#PERIODS;

    # compute the report header
    my $report = '─'
      . join( '─┬─', map '─' x length( sprintf $_, ' ' ), @fmt )
      . "─\n";
    $report .= sprintf ' ' . join( ' │ ', @fmt ) . " \n", @headers;
    $report .= '─'
      . join( '─┼─', map '─' x length( sprintf $_, ' ' ), @fmt )
      . "─\n";

    # compute the actual report
    for my $date ( sort @backups ) {
        $report .= ' '
          . join(
            " │ ",
            sprintf( $fmt[0], basename($date) ),
            map sprintf(
                $fmt[ $_ + 1 ],
                $tag{$date}{ $PERIODS[$_] }
                  . ( $keep{ $PERIODS[$_] }{$date} ? ' *' : '  ' )
            ),
            0 .. $#PERIODS
          ) . " \n";
    }

    # strike backups to be removed with COMBINING LONG STROKE OVERLAY
    $report =~ s/^([^*y┼┬]*)$/$1=~s{(.)}{$1\x{336}}gr/gem
      if $options->{strike};

    return " $store\n$report";
}

sub call ( $self ) {
    my $options = $self->options;

    binmode( STDOUT, ':utf8' );
    for my $store ( $self->arguments->@* ) {
        my @backups = grep -d, grep $_ =~ BACKUP_RX, glob "$store/*";
        print $self->retention_report( $store, @backups ), "\n"
          if @backups;
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

=head2 OPTIONS

=head3 Reporting options

    --strike               strike out the backups to be deleted from the report

=head3 Retention policy options

These options help define the retention policy:

    --keep-days <n>        keep <n> daily backups
    --keep-weeks <n>       keep <n> weekly backups
    --keep-months <n>      keep <n> monthly backups
    --keep-quarters <n>    keep <n> quarterly backups
    --keep-years <n>       keep <n> yearly backups

All options above accept the corresponding aliases.
E.g., I<--days> and I<--daily> are valid aliases for I<--keep-days>.

=head1 DESCRIPTION

B<dumbbackup report> prints a retention report on all the backups found
in the given stores.

The table header summarizes the retention policy.

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
     2024-12-30 Mon * │ 2024-53   │ 2024-12   │ 2024-4      │ 2024      
     2024-12-31 Tue * │ 2024-53 * │ 2024-12 * │ 2024-4 *    │ 2024 *    

The backups to be I<kept> are marked with a C<*> in the generated table.
Anything not marked as retained is going to be deleted when the
B<dumbbackup cleanup> command is run.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
