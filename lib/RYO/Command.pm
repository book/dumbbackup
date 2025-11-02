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

around options_spec => sub ( $orig, @args ) {
    return ( 'help', 'pager!', $orig->(@args) );
};
around options_defaults => sub ( $orig, @args ) {
    return ( pager => 1, $orig->(@args) );
};

has options => (
    is       => 'lazy',
    init_arg => undef,
    builder  => sub ($self) {
        my %options = $self->options_defaults;
        my $parser  = Getopt::Long::Parser->new;
        $parser->configure( $self->getopt_config );
        $parser->getoptionsfromarray( $self->arguments, \%options,
            $self->options_spec )
          or $self->usage_error('');
        \%options;
    },
);

sub BUILD ($self, $args ) {
    $self->options;    # build options from arguments
}

sub validate_options { }

# help-related methods
sub maybe_connect_to_pager ( $self ) {
    my $options = $self->options;
    return if !$options->{pager} || !-t STDOUT;

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

sub usage ( $self, %args ) {
    my $class = $args{class} // ref $self;
    my $file  = "$class.pm" =~ s{::}{/}gr;
    my $input = $INC{$file};
    if ( !-e $input ) {
        eval { require Module::Reader } or do {
            die "Unable to read module $class!\n";
        };
	$input = Module::Reader::module_handle($class);
    }

    # don't use a pager for errors
    $self->maybe_connect_to_pager
      unless $args{is_error};

    my $message = $args{message};
    $message .= "\n" if $message && substr( $message, -1 ) ne "\n";
    $message = ' ' if defined $message && $message eq '';

    Pod::Usage::pod2usage(
        -input  => $input,
        -output => $args{is_error} ? \*STDERR : \*STDOUT,
        ( defined $message ? ( -message => $message ) : () ),
        (
            $args{is_error}
            ? ( -exitval => 2, -verbose => 1 )
            : ( -exitval => 0, -verbose => 2 )
        ),
        -noperldoc => 1,    # perldoc also does some pager detection, skip it
    );

    return 0;
}

sub usage_error ( $self, $message = '' ) {
    $self->usage(
        is_error => 1,
        message  => $message,
    );
}

sub help ( $self ) { $self->usage }

sub run ( $self ) {
    my $options = $self->options;
    if ( $options->{help} ) { $self->help }
    else {
        $self->validate_options;
        eval { $self->call; 1 }
          or do { warn $@; return 1; }
    }
    return 0;
}

1;
