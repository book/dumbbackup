package DumbBackup::Nice;
use 5.024;
use warnings;

use Moo::Role;
use namespace::clean;

use experimental 'signatures';

around options_spec => sub ( $orig, @args ) {
    return (
        $orig->(@args),
        qw(
          nice=i                     ionice=i
          local_nice|local-nice=i    local_ionice|local-ionice=i
          remote_nice|remote-nice=i  remote_ionice|remote-ionice=i
          ),
    );
};

before BUILD => sub ( $self, $args ) {
    my $options = $self->options;
    $options->{local_nice}    //= $options->{nice};
    $options->{remote_nice}   //= $options->{nice};
    $options->{local_ionice}  //= $options->{ionice};
    $options->{remote_ionice} //= $options->{ionice};
};

sub local_nice ($self) {
    my $options = $self->options;
    return (
        ( nice   => '-n', $options->{local_nice}   )x!! $options->{local_nice},
        ( ionice => '-c', $options->{local_ionice} )x!! $options->{local_ionice}
    );
}

sub remote_nice ($self) {
    my $options = $self->options;
    return (
        ( nice   => '-n', $options->{remote_nice}   )x!! $options->{remote_nice},
        ( ionice => '-c', $options->{remote_ionice} )x!! $options->{remote_ionice}
    );
}

1;
