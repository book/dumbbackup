package DumbBackup::Command::Cleanup;
use 5.024;
use warnings;
use utf8;

use POSIX            qw( strftime ceil );
use List::Util       qw( max );
use File::Basename   qw( basename );

use DumbBackup::Constants qw( BACKUP_RX @PERIODS );

use Moo;
use namespace::clean;

use experimental 'signatures';

with
  'RYO::Command',
  'RYO::WithSystemCommands',
  'DumbBackup::RetentionPolicy',
  'DumbBackup::Nice',
  ;

sub options_spec {
    qw( store=s );
}

sub options_defaults { }

sub validate_options ( $self) {
    my $options = $self->options;
    $self->usage_error('--store is required')
      unless $options->{store};
}

sub call ($self) {
    my $options = $self->options;

    # compute the list of backups
    my @backups = grep -d, grep $_ =~ BACKUP_RX, glob "$options->{store}/*";

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

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
