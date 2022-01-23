package DumbBackup;
use 5.024;
use warnings;

use Module::Runtime qw( require_module );

use feature 'signatures';
no warnings 'experimental::signatures';

my %subcommand = (
    backup  => 'Backup',
    run     => 'Backup',
    now     => 'Backup',
    cleanup => 'Cleanup',
    keep    => 'Cleanup',
);

sub run ( $self, @args ) {
    my $cmd = shift @args || '';
    die "Unknown subcommand $cmd\n"
      if !exists $subcommand{$cmd};

    my $class = "DumbBackup::$subcommand{$cmd}";
    require_module($class);
    $class->new( arguments => \@args )->call;
}

1;
