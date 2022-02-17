package DumbBackup::Cleanup;
use 5.024;
use warnings;

use File::Spec       qw();
use POSIX            qw( strftime );
use Fcntl            qw( :flock );
use List::Util       qw( min );
use Text::ParseWords qw( shellwords );
use DumbBackup::Sort qw( by_date );

# force compile-time resolution, see namespace::clean documentation
my $by_date = \&by_date;

use Moo;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

with
  'DumbBackup::Nice',
  'DumbBackup::Command',
  ;

sub options_spec {
    qw(
      store=s
      days|keep-days=i
      months|keep-months=i
      years|keep-years=i
      dry_run|dry-run       verbose
    );
}

sub options_defaults {
    (
        years  => 1,
        months => 6,
        days   => 10,
    );
}

sub BUILD ( $self, $args ) {
    my $options = $self->options;
    die "--store is required\n"
        if !$options->{store};
}

sub call ($self) {
    my $options = $self->options;
    my $today   = strftime "%Y-%m-%d", localtime;
    my $dest    = "$options->{store}/$today";

    my @backups = grep $_ ne $dest, grep -d, glob "$options->{store}/????-??-??";
    my %keep;

    # separate backups in the corresponding buckets
    my ( %y, %m );
    /\b((\d{4})-\d{2})-\d{2}$/
      and push @{ $m{$1} }, $_
      and push @{ $y{$2} }, $_
      for @backups;

    # keep the requested numbers in each sieve
    $keep{$_}++ for grep $_, ( reverse sort $by_date @backups )[ 0 .. $options->{days} - 1 ];
    $keep{ $m{$_}[0] }++
      for grep $_, ( reverse sort $by_date keys %m )[ 0 .. $options->{months} - 1 ];
    $keep{ $y{$_}[0] }++
      for grep $_, ( reverse sort $by_date keys %y )[ 0 .. $options->{years} - 1 ];

    # remove everything we don't want to keep
    my @local_nice  = $self->local_nice;
    for my $bye ( grep !$keep{$_}, @backups ) {
        my @rm = ( @local_nice, rm => '-rf', ( '-v' )x!! $options->{verbose}, $bye);
        $self->run_command(@rm);
    }

}

1;
