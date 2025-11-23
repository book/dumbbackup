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
could restore files by copying them back manually from the archives.

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

  **dumbbackup** is not [bup](https://bup.github.io/).

  The only data deduplication it offers is by hard-linking identicals
  versions of the same file. That means each backup directory is a full
  backup, and having multiple backups of the same version of the same
  file means they all refer to the same location.

  That also implies the backup storage on a server must be on a single
  filesystem (to take advantage of hard links).

* **Full backups, done in an differential way**

  Each backup directory contains a full backup.

  Thanks to hardlinks, multiple copies of the same file across multiple
  backups only use the space once.

  Thanks to `rsync`, the data transfered for backing up an unmodified
  file is minimal.

* **Atomic**

  Only complete backups are stored. Any incomplete backup will be left
  around to be picked up by the next backup run at a later point in time.

* **Remote backups**

  The versatility of `dumbbackup` comes from `rsync`:

  > It can copy locally, to/from another host over any remote shell, or
  > to/from a remote rsync daemon.

  The `--server` and `--target` options should accept any host
  specification that `rsync` accepts. (I've only tested with
  `ssh`, though.)

* **A single script, all-included**

  Although the program logic is now split over multiple modules, you
  only have one script (`dumbbackup`)  to download and install to be
  able to use it.

* **Few dependencies**

  You need to have `perl` (on the machine running the command) and
  `rsync` (both on the server and target) installed. You may also use
  `nice` and `ionice`, if available.

  The minimum Perl version required is v5.24 (published in 2016).

* **Self-documented**

  `dumbackp help` or `dumbbackup --help` is the entry point for
  getting help.

* **Easy cleanup**

  Removing a backup is a easy as running `rm -rf` on it.
  Thanks to hardlinks, the content of a file is only removed
  when the last link to it is removed.

  `dumbbackup cleanup` makes it even easier by generating
  the relevant removal commands, according to the
  [retention policy](#backup-retention-policy).

* **Separation of concerns**

  The `dumbbackup run` and the `dumbbackup clean` commands are completely
  independent:

  * if the cleanup step is not run, backups will accumulate;
  * if the backup step is not run, older backup won't disappear as
    they age.

# Usage

## Backup

To fully backup a host (named `zlonk` in the server's `/root/.ssh/config`)
into the server in the `/backups/zlonk` directory, running `rsync` with
the `--verbose` option, simply type:

    dumbbackup run root@zlonk:/ /backups/zlonk -- --verbose

Backups are atomic, meaning they are built in a temporary directory
(named `.progress`) and only copied to their final location when the
`rsync` process exits with a success status. Once completed, each
backup is stored in a directory named after the local date of the host
that ran the command, in the `strftime` format `%Y-%m-%d_%H-%M-%S`
(or `YYYY-MM-DD_hh-mm-ss` for regular people).

Running the tool several times a day will ensure that if a backup failed
(e.g. network failure), the next run will catch anything that was missed
in the previous run. If all of them are successful, there might be multiple
directories for the same day, but taking up a very small amount of extra
space, thanks to the hard links.

Running `backup cleanup` will apply the retention policy, and keep a
single backup for any given day. (See below.)

It is recommended to run the tool as `root`, so that *all* files can be
backed up.

### Unattended backups and security

To enable unattended backups (the best kind of backups), you'll need
to have a passwordless private key for `ssh`. Obviously, this should
be a key pair dedicated for backups, so that it can easily be revoked
(by removing it from the host `rsync` is connecting to).

Because these are passwordless keys, I'd recommend that you initiate all
backups from the server (so has to keep the private key on the server,
instead of spreading passwordless keys to your backup server on all
the targets...).

It's possible to increase security by only allowing the `rsync`
command to be run using that key pair. This is done by adding
a line like the following to the `.ssh/authorized_keys` file:

    command="/usr/bin/rsync" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... root@server

## Backup retention policy

The `dumbbackup cleanup` (aliases to `dumbbackup keep`) command, run on
the storage server, will remove older backups according to the defined
retention policy.

### Bucketing

For backup retention, backups are categorized into "buckets" of different
types. There are daily, weekly, monthly, quarterly and yearly buckets.

When considering which backups to remove, `dumbbackup clean` marks the
most recent item in the most recent buckets for each periodicity type.
Anything that is not marked to be kept at the end of the process is
eligible to be removed.

The retention strategy can be seen as passing the backups through sieves
with openings of different sizes. There a sieve for each periodicity,
which will only keep the most recent backup in each bucket for the given
periodicity.

The retention policy is expressed in number of items to retain per
periodicity. For example, if the retention is of 6 monthly backups,
the backups will be distributed in monthly buckets, and only the most
recent backup in each of the 6 most recent monthly buckets will be marked
for keeping.

Taking the backup for `2013-10-24` as an example, it belongs to the
following buckets for each periodicity:

* daily: `2013-10-24` (October 24th, 2013)
* weekly: `2013-42` (week 42 of 2013)
* monthly: `2013-10` (October 2013)
* quartely: `2013-3` (third quarter of 2013)
* yearly: `2013`

For the weekly bucket, **dumbbackup** uses the `strftime` format `%G-%V`:
> week 1 is the first week where four or more days fall within the new year
> (or, synonymously, week 01 is: the first week of the year that contains
> a Thursday; or, the week that has 4 January in it).

This ensures all weeks contain seven days. Consider the quirk of the
previously used format of `%Y-%W`, where `2024-12-31` (Tuesday) is in
the same week as `2025-01-01` (Wednesday), but the former is in
the weekly bucket `2024-53` and the latter in the `2025-00` bucket,
thus creating two weekly buckets of respectively two and five days.

The default retention for each periodicity is:

* 7 daily backups
* 5 weekly backups
* 3 monthly backups
* 4 quarterly backups
* 10 yearly backups

That is to say, enough daily backups to cover a week, enough weekly
backups to cover a month, enough monthly backups to cover a quarter,
and enough quartely backups to cover a year. And then 10 yearly backups,
but that could be anything (disk space will expand faster and cheaper
than what's needed for an extra backup per year).

This retention policy would be expressed as follows (if that wasn't
the default):

    dumbbackup keep      \
        --days      7    \
        --weeks     5    \
        --months    3    \
        --quarters  4    \
        --years    10    \
        ...

This ensures that even if backups are skipped, we keep a spread of
backups that is denser when closer to the present day.

### Example

(Note that the reports below only shows backups in the `YYYY-MM-DD`
format, to save some horizontal space. The backup directories actually
contain the time too.)

Assuming the following backups have been saved for a given host,
and none have been cleaned up yet:

    2019-10-11 2019-11-13 2019-11-28 2019-11-29 2019-12-02 2020-01-07
    2020-02-01 2020-02-19 2020-03-09 2020-04-01 2020-05-01 2020-06-08
    2020-06-09 2020-08-27 2020-08-28 2020-08-31 2020-09-14 2021-01-01
    2021-07-01 2021-08-01 2021-09-01 2021-10-01 2021-11-01 2021-12-01
    2021-12-28 2021-12-31 2022-01-01 2022-01-08 2022-01-09 2022-01-10
    2022-01-11 2022-01-12 2022-01-13 2022-01-14

Using the default retention policy, one can run the following command:

    dumbbackup report /backups/zlonk

to produce a table of all the backups that exist for a given target
and their corresponding buckets:

```
  7 daily          │ 5 weekly  │ 3 monthly │ 4 quarterly │ 10 yearly 
───────────────────┼───────────┼───────────┼─────────────┼───────────
  2019-10-11 Fri   │ 2019-41   │ 2019-10   │ 2019-4      │ 2019      
  2019-11-13 Wed   │ 2019-46   │ 2019-11   │ 2019-4      │ 2019      
  2019-11-28 Thu   │ 2019-48   │ 2019-11   │ 2019-4      │ 2019      
  2019-11-29 Fri   │ 2019-48   │ 2019-11   │ 2019-4      │ 2019      
  2019-12-02 Mon   │ 2019-49   │ 2019-12   │ 2019-4      │ 2019 *    
  2020-01-07 Tue   │ 2020-02   │ 2020-01   │ 2020-1      │ 2020      
  2020-02-01 Sat   │ 2020-05   │ 2020-02   │ 2020-1      │ 2020      
  2020-02-19 Wed   │ 2020-08   │ 2020-02   │ 2020-1      │ 2020      
  2020-03-09 Mon   │ 2020-11   │ 2020-03   │ 2020-1      │ 2020      
  2020-04-01 Wed   │ 2020-14   │ 2020-04   │ 2020-2      │ 2020      
  2020-05-01 Fri   │ 2020-18   │ 2020-05   │ 2020-2      │ 2020      
  2020-06-08 Mon   │ 2020-24   │ 2020-06   │ 2020-2      │ 2020      
  2020-06-09 Tue   │ 2020-24   │ 2020-06   │ 2020-2      │ 2020      
  2020-08-27 Thu   │ 2020-35   │ 2020-08   │ 2020-3      │ 2020      
  2020-08-28 Fri   │ 2020-35   │ 2020-08   │ 2020-3      │ 2020      
  2020-08-31 Mon   │ 2020-36   │ 2020-08   │ 2020-3      │ 2020      
  2020-09-14 Mon   │ 2020-38   │ 2020-09   │ 2020-3      │ 2020 *    
  2021-01-01 Fri   │ 2020-53   │ 2021-01   │ 2021-1 *    │ 2021      
  2021-07-01 Thu   │ 2021-26   │ 2021-07   │ 2021-3      │ 2021      
  2021-08-01 Sun   │ 2021-30   │ 2021-08   │ 2021-3      │ 2021      
  2021-09-01 Wed   │ 2021-35   │ 2021-09   │ 2021-3 *    │ 2021      
  2021-10-01 Fri   │ 2021-39   │ 2021-10   │ 2021-4      │ 2021      
  2021-11-01 Mon   │ 2021-44 * │ 2021-11 * │ 2021-4      │ 2021      
  2021-12-01 Wed   │ 2021-48 * │ 2021-12   │ 2021-4      │ 2021      
  2021-12-28 Tue   │ 2021-52   │ 2021-12   │ 2021-4      │ 2021      
  2021-12-31 Fri   │ 2021-52   │ 2021-12 * │ 2021-4 *    │ 2021 *    
  2022-01-01 Sat   │ 2021-52 * │ 2022-01   │ 2022-1      │ 2022      
  2022-01-08 Sat * │ 2022-01   │ 2022-01   │ 2022-1      │ 2022      
  2022-01-09 Sun * │ 2022-01 * │ 2022-01   │ 2022-1      │ 2022      
  2022-01-10 Mon * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
  2022-01-11 Tue * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
  2022-01-12 Wed * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
  2022-01-13 Thu * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
  2022-01-14 Fri * │ 2022-02 * │ 2022-01 * │ 2022-1 *    │ 2022 *    
```

The backups to be *kept* are marked with a `*` in the above table.
Anything not marked as retained is going to be deleted when the actual
command is run.

The actual deletions can be verified with:

```
$ dumbbackup cleanup /backups/zlonk --dry-run
# rm -rf /backups/zlonk/2019-10-11
# rm -rf /backups/zlonk/2019-11-13
# rm -rf /backups/zlonk/2019-11-28
# rm -rf /backups/zlonk/2019-11-29
# rm -rf /backups/zlonk/2020-01-07
# rm -rf /backups/zlonk/2020-02-01
# rm -rf /backups/zlonk/2020-02-19
# rm -rf /backups/zlonk/2020-03-09
# rm -rf /backups/zlonk/2020-04-01
# rm -rf /backups/zlonk/2020-05-01
# rm -rf /backups/zlonk/2020-06-08
# rm -rf /backups/zlonk/2020-06-09
# rm -rf /backups/zlonk/2020-08-27
# rm -rf /backups/zlonk/2020-08-28
# rm -rf /backups/zlonk/2020-08-31
# rm -rf /backups/zlonk/2021-07-01
# rm -rf /backups/zlonk/2021-08-01
# rm -rf /backups/zlonk/2021-10-01
# rm -rf /backups/zlonk/2021-12-28
```

After running `dumbackup cleanup` for real, the remaining backups are:

```
 7 daily          │ 5 weekly  │ 3 monthly │ 4 quarterly │ 10 yearly 
──────────────────┼───────────┼───────────┼─────────────┼───────────
 2019-12-02 Mon   │ 2019-48   │ 2019-12   │ 2019-4      │ 2019 *    
 2020-09-14 Mon   │ 2020-37   │ 2020-09   │ 2020-3      │ 2020 *    
 2021-01-01 Fri   │ 2021-00   │ 2021-01   │ 2021-1 *    │ 2021      
 2021-09-01 Wed   │ 2021-35   │ 2021-09   │ 2021-3 *    │ 2021      
 2021-11-01 Mon   │ 2021-44 * │ 2021-11 * │ 2021-4      │ 2021      
 2021-12-01 Wed   │ 2021-48 * │ 2021-12   │ 2021-4      │ 2021      
 2021-12-31 Fri   │ 2021-52   │ 2021-12 * │ 2021-4 *    │ 2021 *    
 2022-01-01 Sat   │ 2021-52 * │ 2022-01   │ 2022-1      │ 2022      
 2022-01-08 Sat * │ 2022-01   │ 2022-01   │ 2022-1      │ 2022      
 2022-01-09 Sun * │ 2022-01 * │ 2022-01   │ 2022-1      │ 2022      
 2022-01-10 Mon * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
 2022-01-11 Tue * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
 2022-01-12 Wed * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
 2022-01-13 Thu * │ 2022-02   │ 2022-01   │ 2022-1      │ 2022      
 2022-01-14 Fri * │ 2022-02 * │ 2022-01 * │ 2022-1 *    │ 2022 *    
```

When the year rolls over on January 1st, it creates new daily, weekly,
monthly, quarterly and yearly buckets, which will push out the oldest
item in each bucket type.

### Picking a retention policy

When coming up with your own retention policy, it is important to make
sure that the number of kept items for a given periodicity covers a span
of time larger than what is covered by the periodicity below it.

For example, if we keep 12 monthly backups, any number of quarterly
backups that covers less than 12 months will gain nothing, in terms
of going back in time:

```
 7 daily          │ 5 weekly  │ 12 monthly │ 4 quarterly │ 10 yearly 
──────────────────┼───────────┼────────────┼─────────────┼───────────
 2024-01-31 Wed   │ 2024-05   │ 2024-01 *  │ 2024-1      │ 2024      
 2024-02-29 Thu   │ 2024-09   │ 2024-02 *  │ 2024-1      │ 2024      
 2024-03-31 Sun   │ 2024-13   │ 2024-03 *  │ 2024-1 *    │ 2024      
 2024-04-30 Tue   │ 2024-18   │ 2024-04 *  │ 2024-2      │ 2024      
 2024-05-31 Fri   │ 2024-22   │ 2024-05 *  │ 2024-2      │ 2024      
 2024-06-30 Sun   │ 2024-26   │ 2024-06 *  │ 2024-2 *    │ 2024      
 2024-07-31 Wed   │ 2024-31   │ 2024-07 *  │ 2024-3      │ 2024      
 2024-08-31 Sat   │ 2024-35   │ 2024-08 *  │ 2024-3      │ 2024      
 2024-09-30 Mon   │ 2024-40   │ 2024-09 *  │ 2024-3 *    │ 2024      
 2024-10-31 Thu   │ 2024-44   │ 2024-10 *  │ 2024-4      │ 2024      
 2024-11-30 Sat   │ 2024-48   │ 2024-11 *  │ 2024-4      │ 2024      
 2024-12-08 Sun   │ 2024-49 * │ 2024-12    │ 2024-4      │ 2024      
 2024-12-15 Sun   │ 2024-50 * │ 2024-12    │ 2024-4      │ 2024      
 2024-12-22 Sun   │ 2024-51 * │ 2024-12    │ 2024-4      │ 2024      
 2024-12-25 Wed * │ 2024-52   │ 2024-12    │ 2024-4      │ 2024      
 2024-12-26 Thu * │ 2024-52   │ 2024-12    │ 2024-4      │ 2024      
 2024-12-27 Fri * │ 2024-52   │ 2024-12    │ 2024-4      │ 2024      
 2024-12-28 Sat * │ 2024-52   │ 2024-12    │ 2024-4      │ 2024      
 2024-12-29 Sun * │ 2024-52 * │ 2024-12    │ 2024-4      │ 2024      
 2024-12-30 Mon * │ 2025-01   │ 2024-12    │ 2024-4      │ 2024      
 2024-12-31 Tue * │ 2025-01 * │ 2024-12 *  │ 2024-4 *    │ 2024 *    
```

For quarterly backups to make sense in this setup, the number of
quarterly backups kept needs to be at least 5.

Note that the options defining the retention strategy also accept
`0` (do not try to keep any backup for this periodicity) and `-1`
(keep an unlimited number of backups for that periodicity).

### Backup spread

With the default strategy (and ignoring the yearly backups), if we create
new backups every day and apply the retention policy daily, the number
of kept backups will oscillate between 12 and 16.

The widest spread for backups (16) would be similar to:

```
 7 daily          │ 5 weekly  │ 3 monthly │ 4 quarterly │ 0 yearly 
──────────────────┼───────────┼───────────┼─────────────┼──────────
 2024-06-30 Sun   │ 2024-26   │ 2024-06   │ 2024-2 *    │ 2024      
 2024-09-30 Mon   │ 2024-40   │ 2024-09   │ 2024-3 *    │ 2024      
 2024-12-31 Tue   │ 2025-01   │ 2024-12   │ 2024-4 *    │ 2024      
 2025-01-31 Fri   │ 2025-05   │ 2025-01 * │ 2025-1      │ 2025      
 2025-02-09 Sun   │ 2025-06 * │ 2025-02   │ 2025-1      │ 2025      
 2025-02-16 Sun   │ 2025-07 * │ 2025-02   │ 2025-1      │ 2025      
 2025-02-23 Sun   │ 2025-08 * │ 2025-02   │ 2025-1      │ 2025      
 2025-02-28 Fri   │ 2025-09   │ 2025-02 * │ 2025-1      │ 2025      
 2025-03-02 Sun   │ 2025-09 * │ 2025-03   │ 2025-1      │ 2025      
 2025-03-03 Mon * │ 2025-10   │ 2025-03   │ 2025-1      │ 2025      
 2025-03-04 Tue * │ 2025-10   │ 2025-03   │ 2025-1      │ 2025      
 2025-03-05 Wed * │ 2025-10   │ 2025-03   │ 2025-1      │ 2025      
 2025-03-06 Thu * │ 2025-10   │ 2025-03   │ 2025-1      │ 2025      
 2025-03-07 Fri * │ 2025-10   │ 2025-03   │ 2025-1      │ 2025      
 2025-03-08 Sat * │ 2025-10   │ 2025-03   │ 2025-1      │ 2025      
 2025-03-09 Sun * │ 2025-10 * │ 2025-03 * │ 2025-1 *    │ 2025      
```

While the tighest spread of backups (12) would look like this:

```
 7 daily          │ 5 weekly  │ 3 monthly │ 4 quarterly │ 0 yearly 
──────────────────┼───────────┼───────────┼─────────────┼──────────
 2024-06-30 Sun   │ 2024-26   │ 2024-06   │ 2024-2 *    │ 2024     
 2024-09-30 Mon   │ 2024-40   │ 2024-09   │ 2024-3 *    │ 2024     
 2024-11-30 Sat   │ 2024-48   │ 2024-11 * │ 2024-4      │ 2024     
 2024-12-15 Sun   │ 2024-50 * │ 2024-12   │ 2024-4      │ 2024     
 2024-12-22 Sun   │ 2024-51 * │ 2024-12   │ 2024-4      │ 2024     
 2024-12-26 Thu * │ 2024-52   │ 2024-12   │ 2024-4      │ 2024     
 2024-12-27 Fri * │ 2024-52   │ 2024-12   │ 2024-4      │ 2024     
 2024-12-28 Sat * │ 2024-52   │ 2024-12   │ 2024-4      │ 2024     
 2024-12-29 Sun * │ 2024-52 * │ 2024-12   │ 2024-4      │ 2024     
 2024-12-30 Mon * │ 2024-53   │ 2024-12   │ 2024-4      │ 2024     
 2024-12-31 Tue * │ 2024-53 * │ 2024-12 * │ 2024-4 *    │ 2024     
 2025-01-02 Thu * │ 2025-00 * │ 2025-01 * │ 2025-1 *    │ 2025     
```

(Note that `2024-53` and `2025-00` are actually the same week, as discussed earlier.)

The formula for counting maximum number of backups (excluding yearly ones)
is the sum of daily, weekly, monthly and quarterly backups retained minus
3 (because the most recent daily backup is also the most recent weekly,
monthly and quartely backup).

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
  the `backup` and `cleanup` commands.

  The tool is still a single file, thanks to
  `[App::FatPacker](https://metacpan.org/pod/App::FatPacker)`.
  It is generated with the command `pack-script`.

* March 2022

  Added a quarterly bucket to the retention strategy.

* July 2022

  Started documenting the retention policy, and wrote some
  crude script to visualize it.

* October 2025

  Finished including the retention policy in `dumbbackup cleanup`, and
  polished the visualization into a report, that became the output of
  `dumbbackup cleanup --report`. And documented it in detail.

  Added support for showing help via `dumbbackup help` or the `--help`
  option in each subcommmand.

* November 2025

  Rewrote the application with my own new framework for building CLI
  tools, based on an idea I've had for over a decade now: build a
  command-line tool by consuming roles that extend it.

  This allows a role to add support for specific options which, combined
  with clever use of lazy attributes and method modifiers, can easily
  provide a shared set of options across subcommands.

  While re-working the `dumbbackup backup` command, I became aware of a
  number of shortcomings in the generated command-line. I took inspiration
  from [linux-timemachine](https://github.com/cytopia/linux-timemachine)
  to fix them, and improve `dumbbackup`. One of the improvements was to
  ensure backups are only in their final destination when the `rsync`
  command succeeds, so that no incomplete backups risk polluting the
  history.

# See also

`dumbbackup` is not the greatest backup system ever, but it works
well enough for my simple use case.

[There are many other options available.](https://en.wikipedia.org/wiki/List_of_backup_software#Free_and_open-source_software)

And more exist that are not listed in the above Wikipedia page
(in the order I learnt about them):

* [rsnapshot](https://github.com/rsnapshot/rsnapshot)
* [Backup Manager](https://github.com/sukria/Backup-Manager/)
* [linux-timemachine](https://github.com/cytopia/linux-timemachine)
