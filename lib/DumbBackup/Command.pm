package DumbBackup::Command;
use 5.024;
use warnings;

use List::Util qw( uniq );

use Moo;
use namespace::clean;

with
  'RYO::Command',
  'RYO::WithSubcommands',
  ;

sub options_spec     { }
sub options_defaults { }

sub aliases {
    return (
        backup  => 'backup',
        now     => 'backup',
        run     => 'backup',
        save    => 'backup',
        cleanup => 'cleanup',
        keep    => 'cleanup',
        help    => 'help',
        manual  => 'help',
    );
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
