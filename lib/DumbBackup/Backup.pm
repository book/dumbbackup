package DumbBackup::Backup;
use 5.024;
use warnings;

use File::Spec       qw();
use POSIX            qw( strftime );
use Fcntl            qw( :flock );
use List::Util       qw( min );
use Text::ParseWords qw( shellwords );

# a backup sort function
sub by_date {
    my ( $A, $B ) = map /([0-9]{4}(?:-[0-9]{2}(?:-[0-9]{2})?)?)$/, $a, $b;
    return $A cmp $B;
}

# force compile-time resolution, see namespace::clean documentation
my $by_date = \&by_date;

use constant MAX_LINK_DEST => 20;

use Moo;
use namespace::clean;

no warnings 'experimental::signatures';
use feature 'signatures';

with 'DumbBackup::Command';

sub options_spec {
    qw(
      store=s                    others!
      server=s                   target=s
      nice=i                     ionice=i
      local_nice|local-nice=i    local_ionice|local-ionice=i
      remote_nice|remote-nice=i  remote_ionice|remote-ionice=i
      rsync_opts|rsync-opts=s@   exclude=s@
      dry_run|dry-run
    );
}

sub options_defaults {
    (
        timeout => 60,
    );
}

sub BUILD ( $self, $args ) {
    my $options = $self->options;
    die "--server and --target are mutually exclusive\n"
        if $options->{server} && $options->{target};
    die "--store is required\n"
        if !$options->{store};
}

sub acquire_lock ($self) {
    my $options = $self->options;
    my $file = File::Spec->catfile( File::Spec->tmpdir, join '-', 'dumbbackup',
          $options->{server} ? ( server => $options->{server} )
        : $options->{target} ? ( target => $options->{target} )
        :                      ('local') );
    open my $fh, '>', $file
      or die "Can't open $file for writing: $!";
    flock( $fh, LOCK_EX | LOCK_NB )
      or die "Can't acquire lock on $file: $!";
    return [ $fh, $file ];
}

sub release_lock ( $self, $lock ) {
    my ( $fh, $file ) = @$lock;
    close $fh    or warn "Can't close filehandle on $file: $!";
    unlink $file or warn "Can't unlink $file: $!";
}

sub call ( $self ) {
    my $options  = $self->options;
    my $today    = strftime "%Y-%m-%d", localtime;
    my $dest     = "$options->{store}/$today";
    my $base_dir = $options->{store} =~ s{/[^/]*\z}{}r;

    # compute the location data
    # NOTE: might call ssh!
    my ( @backups, @others );
    if ( $options->{server} ) {
        @backups = grep $_ ne $dest, split /\n/,
          qx{ssh $options->{server} ls -d $options->{store}/????-??-??};
        @others = grep $_ ne $dest, split /\n/,
          qx{ssh $options->{server} ls -d $base_dir/*/????-??-??}
          if $options->{others};
        $dest = "$options->{server}:$dest";
    }
    else {
        @backups = grep $_ ne $dest, grep -d, glob "$options->{store}/????-??-??";
        @others  = grep $_ ne $dest, grep -d, glob "$base_dir/*/????-??-??"
          if $options->{others};
    }

    # niceness options
    $options->{local_nice}    //= $options->{nice};
    $options->{remote_nice}   //= $options->{nice};
    $options->{local_ionice}  //= $options->{ionice};
    $options->{remote_ionice} //= $options->{ionice};

    # handle niceness
    my @local_nice = (
      ( nice   => '-n', $options->{local_nice}   )x!! $options->{local_nice},
      ( ionice => '-c', $options->{local_ionice} )x!! $options->{local_ionice}
    );
    my @remote_nice = (
      ( nice   => '-n', $options->{remote_nice}   )x!! $options->{remote_nice},
      ( ionice => '-c', $options->{remote_ionice} )x!! $options->{remote_ionice}
    );

    # rsync options
    my @rsync_opts = qw( -aH --partial --numeric-ids );
    push @rsync_opts, shellwords( $_ ) for @{ $options->{rsync_opts} };
    push @rsync_opts, '--timeout', $options->{timeout}
      if $options;

    # link-dest option: merge self with others, sorted by date
    my @link_dest = ( reverse sort $by_date @backups, @others )
      [ 0 .. min( MAX_LINK_DEST, @backups + @others ) - 1 ];

    # if there are no older self-backups in the selection, push others at the end
    @link_dest =
      ( ( reverse sort $by_date @backups ), ( reverse sort $by_date @others ) )
      [ 0 .. min( MAX_LINK_DEST, @backups + @others ) - 1 ]
      if !grep m{\Q$options->{store}\E}, @link_dest;

    push @rsync_opts, map "--link-dest=$_", @link_dest;

    # remaining arguments are a list of directories to backup
    # assume Unix-like directories with no trailing slash
    my @src;
    my @filters = map "--exclude=$_", $options->{exclude}->@*;
    for ( $self->arguments->@* ) {
        push @src, join ':', $options->{target} || (), $_;
        s{/\z}{};
        push @filters, "--include=$_/**";
        my @dirs = File::Spec->splitdir($_);
        while (@dirs) {
            pop @dirs;
            my $dir = File::Spec->catdir(@dirs);
            push @filters, "--include=$dir" if $dir;
        }
    }

    push @filters, '--exclude=*';
    @filters = do { my %seen; grep !$seen{$_}++, @filters };

    # build the actual command
    my @cmd;
    if ( $options->{target} && @remote_nice ) {
        # TODO: if --rsync-path was passed, replace 'rsync' below by that value
        push @rsync_opts, "--rsync-path=@remote_nice rsync";
    }
    elsif ( @local_nice ) {
        unshift @cmd, @local_nice;
    }

    # build the rsync command
    push @cmd, rsync => @rsync_opts, @filters, @src, $dest;

    # perform the actual backup
    my $lock = $self->acquire_lock;
    my $status = $self->run_command( @cmd );
    $self->release_lock( $lock );
    return $status
}

1;
