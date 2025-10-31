package DumbBackup::Command;
use 5.024;
use warnings;

use String::ShellQuote qw( shell_quote );
use Getopt::Long ();
use Module::Runtime qw( use_module );
use Module::Reader ();
use Pod::Usage qw( pod2usage );


use Moo::Role;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

requires
  'options_spec',
  'options_defaults',
  'call',
  ;

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
        say STDERR '' and $self->show_usage
          unless $parser->getoptionsfromarray( $self->arguments, \%options,
            help => $self->options_spec );
        \%options;
    },
);

around options_spec => sub ( $orig, @args ) {
    return ( qw( help pager! ), $orig->(@args) );
};

around options_defaults => sub ( $orig, @args ) {
    return ( pager => 1, $orig->(@args) );
};

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

# help-related methods
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

sub show_usage ( $self, $class = ref $self ) {
    my $module = Module::Reader->new->module( $class );
    pod2usage(
        -verbose => 1,
        -input   => $module->handle,
	-output  => \*STDERR,
    );
    exit 1;
}

sub show_help ( $self, $class = ref $self ) {
    my $module = Module::Reader->new->module($class);
    $self->maybe_connect_to_pager;
    pod2usage(
        -verbose => 2,
        -input   => $module->handle,
	-output  => \*STDOUT,
    );
    exit 0;
}

# short-circuit the --help option
around call => sub ( $orig, $self, @args ) {
    $self->options->{help}
      ? $self->show_help()
      : $orig->( $self, @args );
};

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

1;
