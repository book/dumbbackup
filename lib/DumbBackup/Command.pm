package DumbBackup::Command;
use 5.024;
use warnings;

use String::ShellQuote qw( shell_quote );
use Getopt::Long ();

use Moo::Role;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

has arguments => (
    is      => 'ro',
    default => sub { [] },
);

has options => (
    is       => 'lazy',
    init_arg => undef,
    builder  => sub ($self) {
        my %options = $self->options_defaults;
        my $parser  = Getopt::Long::Parser->new;
        #$parser->configure( );
        my $passed =
          $parser->getoptionsfromarray( $self->arguments, \%options,
            $self->options_spec );
        die "Error in command line arguments\n" if !$passed;
        \%options;
    },
);

sub module_for_command ( $self, $command ) {
    state $module_for_command = {
        backup  => 'DumbBackup::Backup',
        run     => 'DumbBackup::Backup',
        now     => 'DumbBackup::Backup',
        cleanup => 'DumbBackup::Cleanup',
        keep    => 'DumbBackup::Cleanup',
        help    => 'DumbBackup::Help',
    };
    return $module_for_command->{$command} // '';
}

# a wrapper around system
sub run_command ($self, @cmd ) {
    say "# ", shell_quote(@cmd)
      if $self->options->{verbose} || $self->options->{dry_run};
    return 0 if $self->options->{dry_run};

    system @cmd;

    my $status = $? >> 8;
    if ( $? == -1 ) {
        die "Failed to execute '$cmd[0]': $!\n";
    }
    elsif ( $? & 127 ) {
        die sprintf "'$cmd[0] died with signal %d, %s coredump\n",
          ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
    }
    else {
        if ( my $status = $? >> 8 ) {
            warn "'$cmd[0]' failed with status $status\n";
            exit $status;
        }
    }

    return $status;
}

requires
  'options_spec',
  'options_defaults',
  ;

1;
