package DumbBackup::Help;
use 5.024;
use warnings;

use Module::Reader ();
use Pod::Usage qw( pod2usage );

use Moo;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

with
  'DumbBackup::Command',
  ;

sub options_spec     { qw( pager! ) }
sub options_defaults { ( pager => 1 ) }

sub show_help_for ( $self, $class ) {
    my $module = Module::Reader->new->module($class);
    pod2usage(
        -verbose => 2,
        -input   => $module->handle,
        -output  => \*STDOUT,          # should be the default
    );
}

sub maybe_connect_to_pager ( $self ) {
    my $options = $self->options;
    return unless $options->{pager} && -t STDOUT;

    # find eligible pager
    my $pager = $ENV{PAGER};           # in the environment
    ($pager) = map +( split / / )[0],  # keep the command
      grep { `$_`; $? >= 0 }           # from trying to run
      'less -V', 'more -V'             # the usual suspects
      unless $pager;

    $ENV{LESS} ||= 'FRX';              # less-specific options

    # fork and exec the pager
    if ( open STDIN, '-|' ) {
        exec $pager or warn "Couldn't exec '$pager': $!";
        exit;
    }
    return;
}

sub call ( $self ) {
    my $options = $self->options;
    my $command = shift $self->arguments->@*;
    my $class   = $command ? $self->module_for_command($command) : 'DumbBackup';
    die "Unknown subcommand '$command'\n"
      unless $class;

    $self->maybe_connect_to_pager;
    $self->show_help_for($class);
}

1;

__END__

=head1 NAME

dumbackup help - Get help on dumbbackup

=head1 SYNOPSIS

  dumbbackup help <command>

  dumbbackup <command> --help

=head1 DESCRIPTION

B<dumbbackup help> provides help on any B<dumbbackup> subcommand.

It will show the help for B<dumbbackup> itself when called with no arguments.

It will automatically connect to a pager is one is defined in the C<PAGER>
environment variable, or if one of the usual suspects (B<less>, B<more>)
can be found.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
