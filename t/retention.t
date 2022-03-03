use 5.024;
use warnings;
use Test::More;

use Time::Local qw( timegm );
use POSIX qw( strftime );
use DumbBackup::Cleanup;

# test bucket computation
my @bucket_tests = (
    '2022-06-01' => {
        days     => '2022-06-01',
        weeks    => '2022-22',
        months   => '2022-06',
        quarters => '2022-2',
        years    => '2022',
    },
    '2022-07-01' => {
        days     => '2022-07-01',
        weeks    => '2022-26',
        months   => '2022-07',
        quarters => '2022-3',
        years    => '2022',
    },
    '2023-01-01' => {
        days     => '2023-01-01',
        weeks    => '2023-00',
        months   => '2023-01',
        quarters => '2023-1',
        years    => '2023',
    },
    '2023-12-31' => {
        days     => '2023-12-31',
        weeks    => '2023-52',
        months   => '2023-12',
        quarters => '2023-4',
        years    => '2023',
    },
);

while ( my ( $date, $buckets ) = splice @bucket_tests, 0, 2 ) {
    is_deeply( { DumbBackup::Cleanup::_buckets_for($date) },
        $buckets, "buckets for $date" );
}

# build 2 years worth of backups starting from 2022-01-01
my @backups;
my $t = timegm( 0, 0, 0, 1, 0, 122 );
while ( my $date = strftime( "%Y-%m-%d", gmtime($t) ) ) {
    last if $date gt '2023-12-31';
    push @backups, $date;
}
continue { $t += 86400; }

# result with default arguments
my $db   = DumbBackup::Cleanup->new( arguments => [qw( --store . )] );
my @kept = sort keys $db->retention_hash(@backups)->%*;
is_deeply(
    \@kept,
    [
        '2022-01-01',    # last yearly (2)
        '2023-01-01',
        '2023-04-01',    # last quarterly (3)
        '2023-07-01',
        '2023-10-01',
        '2023-11-01',    # last monthly (2)
        '2023-12-01',
        '2023-12-04',    # last weekly (4)
        '2023-12-11',
        '2023-12-18',
        '2023-12-25',
        '2023-12-26',    # last daily (6)
        '2023-12-27',
        '2023-12-28',
        '2023-12-29',
        '2023-12-30',
        '2023-12-31',    # Sunday
    ],
    "cleanup two years of backups with default arguments"
);

# example from the docs
is_deeply(
    [
        sort keys $db->retention_hash(
            '2019-12-02',    # drop
            '2020-01-07',    # drop
            '2020-02-19',    # drop
            '2020-05-17',    # last quarterly
            '2021-07-08',    # last yearly
            '2021-09-14',    # last weekly
            '2022-01-19',
            '2022-01-20',    # last daily
            '2022-02-17',    # last monthly
            '2022-02-18',
            '2022-02-28',
            '2022-03-01',
            '2022-03-02',
        )->%*
    ],
    [
        '2020-05-17',
        '2021-07-08',
        '2021-09-14',
        '2022-01-19',
        '2022-01-20',
        '2022-02-17',
        '2022-02-18',
        '2022-02-28',
        '2022-03-01',
        '2022-03-02',
    ],
    "cleanup example backups with default arguments"
);

done_testing;
