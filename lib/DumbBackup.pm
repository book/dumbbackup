package DumbBackup;
use 5.024;
use warnings;

use Module::Runtime qw( require_module );
use DumbBackup::Command;

use feature 'signatures';
no warnings 'experimental::signatures';

sub run ( $self, @args ) {
    my $command = shift @args || '';
    $command = 'help' if $command =~ /\A--?h(?:e(?:l(?:p)?)?)?\z/;
    my $class = DumbBackup::Command->module_for_command($command);
    die "Unknown subcommand $command\n"
      unless $class;

    require_module($class);
    $class->new( arguments => \@args )->call;
}

1;

__END__

=head1 NAME

dumbbackup - Better dumb backups now, than perfect backups too late.

=head1 SYNOPSIS

  dumbbackup <command> [options]

Commands for backup management:

  run     - Perform a backup
  keep    - Apply the retention policy

Miscellaneous command:

  help    - Show the manual page for the given command

=head1 DESCRIPTION

B<dumbbackup> is the simplest backup solution I could think of,
to have some form of backup while I was looking for a perfect
solution.

Most commands have aliases. Check their documentation for details.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
