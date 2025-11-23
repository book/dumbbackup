package DumbBackup::Command::Backup;
use 5.024;
use warnings;

use File::Spec       qw();
use POSIX            qw( strftime );
use Fcntl            qw( :flock );
use List::Util       qw( min );
use Text::ParseWords qw( shellwords );
use DumbBackup::Sort qw( by_date );
use DumbBackup::Constants qw( BACKUP_GLOB );

# force compile-time resolution, see namespace::clean documentation
my $by_date = \&by_date;

use constant MAX_LINK_DEST => 20;
use constant PARTIAL       => '.partial';
use constant IN_PROGRESS   => '.inprogress';

use Moo;
use namespace::clean;

use experimental 'signatures';

with
  'RYO::Command',
  'RYO::WithSystemCommands',
  'DumbBackup::Nice',
  ;

sub getopt_config { qw( pass_through ) }    # keep the --

sub options_spec {
    qw(
      dry_run|dry-run
      others!
    );
}

sub options_defaults { }

sub list_backups ( $self, $host, $path, $glob = BACKUP_GLOB ) {

    # temporarily close STDERR to quiet ls errors
    open my $stderr, '>&', \*STDERR;
    close STDERR;

    # get the list of backup using the glob
    my @backups = $host
      ? split /\n/, qx{ssh $host ls -d "$path/"$glob}
      : grep -d, glob qq{"$path"/$glob};

    # restore STDERR
    open STDERR, '>&', $stderr;
    return @backups;
}

sub build_rsync_src_dest_opts ($self) {
    my $options = $self->options;

    # separate the arguments from the rsync options
    my ( @args, @rsync_opts );
    {
        my %args   = ( self => \@args, rsync => \@rsync_opts );
        my $bucket = 'self';
        for my $arg ( $self->arguments->@* ) {
            if ( $arg eq '--' ) {    # preserved by pass_through
                $bucket = 'rsync';
                next;
            }
            push $args{$bucket}->@*, $arg;
        }
    }

    # BIG ASSUMPTION: "rsync arguments" contain no path definitions
    #
    # Meaning that we don't expect anything like:
    #
    #   dumbbackup run src1 src2 -- [rsync-opts] src3 dst
    #
    # but instead
    #
    #   dumbbackup run src1 src2 src3 dst -- [rsync-opts]
    #
    # To properly process rsync-opts for paths, we'd need to have a
    # hardcoded list of all rsync options that take arguments, and move
    # anything that is not an argument out of @rsync_opts and into @args
    # (that sounds like a lot of work for very little gain)
    # - rsync can take multiple sources and will complain
    #   if remote and local sources are mixed
    # - rsync supports mixing paths and options,
    #   and @args may or may not contain paths for rsync,
    #   so don't reorder things and keep @rsync_opts at the end
    $self->usage_error("At least one source and one destination are required!")
      if @args < 2;

    # inject default rsync options
    unshift @rsync_opts,           # default options for rsync:
      '--recursive',               # recurse into directories
      '--links',                   # copy symlinks as symlinks
      '--perms',                   # preserve permissions
      '--times',                   # preserve modification times
      '--group',                   # preserve group
      '--owner',                   # preserve owner (super-user only)
      '--hard-links',              # preserve hard links
      '--numeric-ids',             # don't map uid/gid values by user/group name
      '--partial',                 # keep partially transferred files
      "--partial-dir=${\PARTIAL}", # put a partially transferred file into DIR
      ;

    # inject nice values on the remote
    if ( my @remote_nice = $self->remote_nice ) {
        my $added;
        for ( 0 .. $#rsync_opts ) {
            if ( $rsync_opts[$_] eq '--rsync-path' && $_ < $#rsync_opts ) {
                $rsync_opts[ $_ + 1 ] = "@remote_nice $rsync_opts[$_+1]";
                $added++;
            }
            else {
                $rsync_opts[$_] =~ s{\A--rsync-path=}{$&@remote_nice }
                  and $added++;
            }
        }
        push @rsync_opts, "--rsync-path=@remote_nice rsync"
          unless $added;
    }

    # split the destination into host and path
    my $dest = pop @args;    # this might be wrong (see BIG ASSUMPTON above)
    my ( $dest_host, $dest_path );
    if ( $dest =~ /:/ ) {
        ( $dest_host, $dest_path ) = split /:/, $dest, 2;
        if ( !$dest_path ) {
            $self->usage_error("Invalid destination '$dest'")
              if !$dest_host;
            $dest_path = qx{ssh $dest_host pwd};
        }
    }
    else { $dest_path = $dest }
    $dest_path =~ s{/+\z}{};

    # extract relevant values from $dest_path
    my ( $base_dir, $name ) = do {
        my @segments = split m{/}, $dest_path;
        my $last     = pop @segments;
        ( join( '/', @segments ), $last );
    };

    # find which other directories to link to with --link-dest
    my ( @backups, @others );
    @backups = $self->list_backups( $dest_host, $dest_path );
    @others  = grep !m{/$name/},
      $self->list_backups( $dest_host, $base_dir, "*/${\BACKUP_GLOB}" )
      if $options->{others};

    # link-dest option: merge self with others, sorted by date
    my @link_dest = ( reverse sort $by_date @backups, @others )
      [ 0 .. min( MAX_LINK_DEST, @backups + @others ) - 1 ];

    # if the host hasn't been backed up for a while, and because the
    # link-dest candidates are sorted by date, the list of directories
    # option might only contain directories for "others"
    #
    # so, if there are no self-backups in the selection,
    # build it again, with self-backups first, and others at the end
    @link_dest =
      ( ( reverse sort $by_date @backups ), ( reverse sort $by_date @others ) )
      [ 0 .. min( MAX_LINK_DEST, @backups + @others ) - 1 ]
      if !grep m{/$name/}, @link_dest;

    # build the link-dest option
    push @rsync_opts, map "--link-dest=$_", @link_dest;

    # return the arguments and options for rsync
    return ( \@args, $dest, \@rsync_opts );
}

sub call ( $self ) {
    my $options = $self->options;
    my $today   = strftime "%Y-%m-%d_%H-%M-%S", localtime;
    my ( $src, $dest, $opts ) = $self->build_rsync_src_dest_opts;

    # build the actual command-line and run it
    my $in_progress = join '/', $dest, IN_PROGRESS;
    my $status = $self->run_command(
        $self->local_nice,    # optional nice
        rsync => @$src => $in_progress,    # rsync SRC... DEST
        @$opts                             # options
    );

    # once the backup succeeds, move it to its final destination
    if (
        $status == 0        # Success
        || $status == 24    # Partial transfer due to vanished source files
      )
    {
        # WARNING: this does not work if the destination already exists!
        if ( $dest =~ /:/ ) {
            my ( $dest_host, $dest_path ) = split /:/, $dest, 2;
            $status = $self->run_command(
                ssh => $dest_host,
                mv  => "$dest_path/${\IN_PROGRESS}" => "$dest_path/$today"
            );
        }
        else {
            say "# mv '$in_progress' '$dest/$today'"
              if $options->{dry_run} || $options->{verbose};
            rename $in_progress, "$dest/$today"
              or die "Can't rename $in_progress to $dest/$today: $!"
              unless $self->options->{dry_run};
        }
    }

    return $status;
}

1;

__END__

=pod

=head1 NAME

dumbbackup backup - Perform a dumb backup using rsync

=head1 SYNOPSIS

  dumbbackup backup [options] source... destination -- [rsync options]

Aliases: C<backup>, C<now>, C<run>, C<save>.

=head2 OPTIONS

    --dry-run              print the commands but don't execute them

    --others               include other backups in the --link-dest option

    --local-nice   <n>     nice level to apply to the local `rsync` command
    --local-ionice <n>     ionice level to apply to the local `rsync` command
    --remote-nice   <n>    nice level to apply to the remote `rsync` command
    --remote-ionice <n>    ionice level to apply to the remote `rsync` command

The I<--nice> and I<--ionice> options will respectively apply to both the
I<--local-nice>/I<--remote-nice> and I<--local-ionice>/I<--remote-ionice>
options.

=head1 DESCRIPTION

C<dumbbackup backup> backups a given host on the server.

Just like B<rsync>, the command can take multiple sources and a single
destination. The backup will be stored in a directory named after the
start date of the backup, below the destination directory.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2013-2025 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
