# `dumbbackup`

> I'd rather have dumb backups now, than perfect backups too late.

After I gave up on [BackupPC](https://backuppc.github.io/backuppc/)
(version 3), I was left without a backup strategy. For a while, I
fantasized about building my own backup system, which was getting more
features as I thought about it, but very little in terms of
implementation. It's easy to solve problems when you never write the
code that actually does it...

Not having any backups, I wasn't feeling very safe about my data.

So I decided to go with a very simple strategy: back everything up with
`rsync` *now* on my remote server (and later, NAS) so nothing horribly
catastrophic and unrecoverable would happen to my data. Worst case, I
could restore files by copying them back from the archives.

# Installation

This repository provides a fatpacked version of the script.

Just copy the `dumbbackup` file, e.g. in `/usr/local/bin`, and make it
executable:

    sudo curl --silent --create-dirs \
        --output /usr/local/bin/dumbbackup \
        https://raw.githubusercontent.com/book/dumbbackup/master/dumbbackup
    sudo chmod a+x /usr/local/bin/dumbbackup

# Features

* **Dumb**

  Backups are made by `rsync`-ing a tree to a backup location. This is
  the ~dumbest~ simplest backup scheme ever.

* **Some data deduplication**

  `dumbbackup` is not [bup](https://bup.github.io/).

  The only data deduplication it offers is by hard-linking identicals
  versions of the same file. That means each backup directory is a full
  backup, and having multiple backups of the same version of the same
  file means they all refer to the same location.

  That also implies the backup storage on a server must be on a single
  filesystem (to take advantage of hard links).

* **Full backups, done in an differential way**

  Each backup directory contains a full backup.

  Thanks to hardlinks, multiple copies of the same file acrosse multiple
  backups only use the space once.

  Thanks to `rsync`, the data transfered for backing up an unmodified
  file is minimal.

* **Remote backups**

  The versatility of `dumbbackup` comes from `rsync`:

  > It can copy locally, to/from another host over any remote shell, or
  > to/from a remote rsync daemon.

  The `--server` and `--target` options should accept any host
  specification that `rsync` accepts. (I've only tested with
  `ssh`, though.)

* **A single script, all-included**

  Although the logic of `dumbbackup` is now split over multiple modules,
  you only have one script to download and install to use it.

* **Few dependencies**

  You need to have `perl` (on the machine running the command) and
  `rsync` (both on the server and target) installed. You may also use
  `nice` and `ionice`, if available.

  The minimum Perl version required is v5.24 (published in 2016).

* **Easy cleanup**

  Removing a backup is a easy as running `rm -fr` on it.
  Thanks to hardlinks, the content of a file is only removed
  when the last link to it is removed.

# History

* October 2013

  The first version was a shell script that would generate and execute
  an `rsync` command similar to this:

      rsync -aH --partial --log-file=/backup/2022-01-18.log --exclude=* / /backup/2013-10-24

* January 2014

  The script grew slowly, acquiring more and more options, until it
  became silly to keep doing it in shell. So I eventually rewrote
  it in Perl.

* January 2022

  Again, the script ended up doing many things and became unwieldy, so I
  split it into several subcommands started by the same frontend.

  This made it easier to separate the concerns and requirements between
  the `backup` and `cleanup` command.

  The tool is still a single file, thanks to `App::FatPacker`. It is
  generated with the command `pack-script`.

# See also

`dumbbackup` is not the greatest backup system ever, but it works
well enough for my simple use case.

[There are many other options available.](https://en.wikipedia.org/wiki/List_of_backup_software#Free_and_open-source_software)
