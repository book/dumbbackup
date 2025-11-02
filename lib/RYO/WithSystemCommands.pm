package RYO::WithSystemCommands;
use 5.024;
use warnings;

use String::ShellQuote qw( shell_quote );

use Moo::Role;
use namespace::clean;

use experimental 'signatures';

around options_spec => sub ( $orig, @args ) {
    return ( 'dry_run|dry-run', 'verbose', $orig->(@args) );
};

sub run_command ( $self, @cmd ) {
    my $options = $self->options;
    say "# ", shell_quote(@cmd)
      if $options->{verbose} || $options->{dry_run};
    return 0 if $options->{dry_run};

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
