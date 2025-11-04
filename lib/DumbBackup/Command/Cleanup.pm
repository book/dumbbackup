package DumbBackup::Command::Cleanup;
use 5.024;
use warnings;
use utf8;

use POSIX            qw( strftime ceil );
use List::Util       qw( max );

use Moo;
use namespace::clean;

use experimental 'signatures';

with
  'RYO::Command',
  'RYO::WithSystemCommands',
  'DumbBackup::Nice',
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

# default to keep is:
# enough of one periodicity to cover the enclosing periodicity
sub options_defaults {
    (
        days     => 7,     # a week is 7 seven days
        weeks    => 5,     # a month is 5 weeks (at most)
        months   => 3,     # a quarter is 3 months
        quarters => 4,     # a year is 4 quarters
        years    => 10,    # could be anything
    );
}

sub validate_options ( $self) {
    my $options = $self->options;
    $self->usage_error('--store is required')
      unless $options->{store};
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

__END__

=encoding utf-8

=head1 NAME

dumbbackup cleanup - Clean up old backups, according to the retention policy

=head1 SYNOPSIS

  dumbbackup cleanup [options]

Aliases: C<cleanup>, C<keep>.

=head2 OPTIONS

=head3 Required options

    --store <directory>    the backup store to cleanup

=head3 Removal options

    --verbose              print the commands as they are executed
    --dry-run              print the commands but don't execute them

    --nice   <n>           nice level to apply to the `rm` commands
    --ionice <n>           ionice level to apply to the `rm` commands

The I<--nice> and I<--ionice> options respectively accept the aliases
I<--local-nice> and I<--local-ionice> (since the C<rm> commands are
run locally).

=head3 Retention policy options

These options help define the retention policy:

    --keep-days <n>        keep <n> daily backups
    --keep-weeks <n>       keep <n> weekly backups
    --keep-months <n>      keep <n> monthly backups
    --keep-quarters <n>    keep <n> quarterly backups
    --keep-years <n>       keep <n> yearly backups

All options above accept the corresponding aliases.
E.g., I<--days> and I<--daily> are valid aliases for I<--keep-days>.

=head3 Reporting options

    --report               print the retention report for the store
    --strike               strike the backups to be deleted from the report

=head1 DESCRIPTION

C<dumbbackup cleanup> removes from the given store the backups that
are not protected by the retention policy.

This command will remove the backups, unless it's passed on of the
I<--dry-run> or I<--report> options.

=head2 Retention policy

The retention policy is defined by the I<--keep-...> options, which indicate
how many backups to keep for each periodicity bucket (daily, weekly, monthly,
quarterly, yearly).

The default retention policy is to keep:

=over 4

=item 7 daily backups

=item 5 weekly backups

=item 3 monthly backups

=item 4 quarterly backups

=item 10 yearly backups

=back

That is to say, enough daily backups to cover a week, enough weekly
backups to cover a month, enough monthly backups to cover a quarter,
and enough quartely backups to cover a year. And 10 yearly backups.

=head2 Retention reports

The I<--report> option will print a retention report on all the backups
found in the store.

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
Anything not marked as retained is going to be deleted when the actual
command is run.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
