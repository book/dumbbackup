package DumbBackup;
use 5.024;
use warnings;

use Module::Runtime qw( require_module );
use DumbBackup::Command;

use feature 'signatures';
no warnings 'experimental::signatures';

sub run ( $self, @args ) {
    my $command = shift @args || '';
    my $class   = DumbBackup::Command->module_for_command($command);
    die "Unknown subcommand $command\n"
      unless $class;

    require_module($class);
    $class->new( arguments => \@args )->call;
}

1;
