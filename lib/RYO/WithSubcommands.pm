package RYO::WithSubcommands;
use 5.024;
use warnings;

use List::Util qw( uniq );

use Moo::Role;
use namespace::clean;

use experimental 'signatures';

requires 'usage_error';

around getopt_config => sub ( $orig, @args ) {
    return ( qw( require_order pass_through ), $orig->(@args) );
};

sub package_prefix ($self) { ref $self }

# an empty aliases method implies that
# no abbreviations will be supported
sub aliases { }

sub resolve_alias ( $self, $command ) {
    my %alias      = $self->aliases;
    my @candidates = sort grep /\A$command/, uniq %alias;
    $self->usage_error("Ambiguous command '$command': @candidates")
      if @candidates > 1;
    my $cmd = shift @candidates;
    return $cmd ? $alias{$cmd} // $cmd : $command;
}

sub resolve_subcommand ( $self, $command ) {

    $self->usage_error('No command specified!')
      if !defined $command;

    $self->usage_error("Invalid command: '$command'")
      if $command !~ /\A[a-z]+(?:-[a-z]+)*\z/;

    $command = $self->resolve_alias($command);

    my $module = $command =~ s/(?:\A|-)(.)/\u$1/gr;
    $module = $self->package_prefix . "::$module";
    my $file = "$module.pm" =~ s{::}{/}gr;
    eval { require $file } or do {
        my $error = $@;
        if ( $error =~ /\ACan't locate \Q$file\E / ) {
            $self->usage_error("Unknown command: '$command'");
        }
        else { die $error }
    };

    return $module;
}

sub call ($self) {
    my $command = shift $self->arguments->@*;
    exit $self->resolve_subcommand($command)->new(
        parent    => $self,
        arguments => [ $self->arguments->@* ],
    )->run;
}

1;
