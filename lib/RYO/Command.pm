package RYO::Command;
use 5.024;
use warnings;

use Getopt::Long ();
use Pod::Usage qw( pod2usage );

use Moo::Role;
use namespace::clean;

use experimental 'signatures';

requires
  'options_spec',
  'options_defaults',
  ;

has parent => (
    is      => 'ro',
    default => '',
);

has arguments => (
    is      => 'ro',
    default => sub { [] },
);

sub getopt_config { }

has options => (
    is       => 'lazy',
    init_arg => undef,
    builder  => sub ($self) {
        my %options = $self->options_defaults;
        my $parser  = Getopt::Long::Parser->new;
        $parser->configure( $self->getopt_config );
        my $passed =
          $parser->getoptionsfromarray( $self->arguments, \%options,
            $self->options_spec );
        die "Error in command line arguments\n" if !$passed;
        \%options;
    },
);

sub BUILD ($self, $args ) {
    $self->options;    # build options from arguments
}

sub validate_options { }

sub run ( $self ) {
    $self->validate_options;
    eval { $self->call; 1 }
      or do { warn $@; return 1; }
      return 0;
}

1;
