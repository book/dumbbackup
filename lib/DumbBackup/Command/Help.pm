package DumbBackup::Command::Help;
use 5.024;
use warnings;

use Moo;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

with
  'RYO::Command',
  ;

sub options_spec     { }
sub options_defaults { }

sub call ( $self ) {
    my $command = shift $self->arguments->@*;
    my $class = $command
      ? $self->parent->resolve_subcommand($command)
      : ref $self->parent;
    $self->usage( class => $class );
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
