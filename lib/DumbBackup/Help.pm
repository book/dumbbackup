package DumbBackup::Help;
use 5.024;
use warnings;

use Module::Reader;
use Pod::Usage;

use Moo;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

with
  'DumbBackup::Command',
  ;

sub options_spec     { }
sub options_defaults { }

sub call ( $self ) {
    my $options = $self->options;
    my $command = shift $self->arguments->@*;
    my $class   = $command ? $self->module_for_command($command) : 'DumbBackup';
    die "Unknown subcommand '$command'\n"
      unless $class;

    my $module = Module::Reader->new->module($class);
    pod2usage(
        -verbose => 2,
        -input   => $module->handle,
    );
}

1;

__END__

=head1 NAME

dumbackup help - Get help on dumbbackup

=head1 SYNOPSIS

  dumbbackup help <command>

=head1 DESCRIPTION

B<dumbbackup help> provides help on any B<dumbbackup> subcommand.

It will show the help for B<dumbbackup> itself when called with no arguments.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
