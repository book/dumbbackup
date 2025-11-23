use 5.024;
use warnings;
use Test::More;

use Time::Local qw( timegm );
use POSIX qw( strftime );
use DumbBackup::Command::Cleanup;

# test bucket computation
my @bucket_tests = (
    '2022-06-01' => {
        days     => '2022-06-01 Wed',
        weeks    => '2022-22',
        months   => '2022-06',
        quarters => '2022-2',
        years    => '2022',
    },
    '2022-07-01' => {
        days     => '2022-07-01 Fri',
        weeks    => '2022-26',
        months   => '2022-07',
        quarters => '2022-3',
        years    => '2022',
    },
    '2023-01-01' => {
        days     => '2023-01-01 Sun',
        weeks    => '2023-00',
        months   => '2023-01',
        quarters => '2023-1',
        years    => '2023',
    },
    '2023-12-24' => {
        days     => '2023-12-24 Sun',
        weeks    => '2023-51',
        months   => '2023-12',
        quarters => '2023-4',
        years    => '2023',
    },
    '2023-12-31' => {
        days     => '2023-12-31 Sun',
        weeks    => '2023-52',
        months   => '2023-12',
        quarters => '2023-4',
        years    => '2023',
    },
);

my $expected_buckets;
my @dates;
while ( my ( $date, $buckets ) = splice @bucket_tests, 0, 2 ) {
    push @dates, $date;
    push $expected_buckets->{$_}{ $buckets->{$_} }->@*, $date
      for keys %$buckets;
}

is_deeply( DumbBackup::Command::Cleanup::_buckets_for( @dates ),
    $expected_buckets, '_buckets_for' );

# build 2 years worth of backups starting from 2022-01-01
my @backups;
my $t = timegm( 0, 0, 0, 1, 0, 122 );
while ( my $date = strftime( "%Y-%m-%d", gmtime($t) ) ) {
    last if $date gt '2023-12-31';
    push @backups, $date;
}
continue { $t += 86400; }

# result with default arguments
my $db   = DumbBackup::Command::Cleanup->new( arguments => [qw( --store . )] );
my @kept = sort keys $db->retention_hash(@backups)->%*;
is_deeply(
    \@kept,
    [
        '2022-12-31',    # last yearly (3)
        '2023-03-31',    # last quarterly (4)
        '2023-06-30',
        '2023-09-30',
        '2023-10-31',    # last monthly (3)
        '2023-11-30',
        '2023-12-03',    # last weekly (5)
        '2023-12-10',
        '2023-12-17',
        '2023-12-24',
        '2023-12-25',    # last daily (7)
        '2023-12-26',
        '2023-12-27',
        '2023-12-28',
        '2023-12-29',
        '2023-12-30',
        '2023-12-31',    # Sunday
    ],
    "cleanup two years of backups with default arguments"
);

push @kept, '2024-01-01';    # one more backup
is_deeply(
    [ sort keys $db->retention_hash(@kept)->%* ],
    [
        '2022-12-31',    # last yearly (3)
        '2023-06-30',    # last quarterly (4)
        '2023-09-30',
        '2023-11-30',    # last monthly (3)
        '2023-12-10',    # last weekly (5)
        '2023-12-17',
        '2023-12-24',
        '2023-12-26',    # last daily (7)
        '2023-12-27',
        '2023-12-28',
        '2023-12-29',
        '2023-12-30',
        '2023-12-31',    # Sunday
        '2024-01-01',
    ],
    "cleanup previous set after passing the boundary for week, month, quarter and year"
);

# example from the docs
is_deeply(
    [
        sort keys $db->retention_hash(
            '2019-12-02',    # last yearly
            '2020-01-07',    # drop
            '2020-02-19',    # last quarterly
            '2020-05-17',
            '2021-07-08',    # last weekly
            '2021-09-14',
            '2022-01-19',    # last daily
            '2022-01-20',    # last monthly
            '2022-02-17',
            '2022-02-18',    # mix with new style
            '2022-02-18_12-34-56',
            '2022-02-28',
            '2022-03-01',
            '2022-03-02',
        )->%*
    ],
    [
        '2019-12-02',
        '2020-02-19',
        '2020-05-17',
        '2021-07-08',
        '2021-09-14',
        '2022-01-19',
        '2022-01-20',
        '2022-02-17',
        '2022-02-18_12-34-56',
        '2022-02-28',
        '2022-03-01',
        '2022-03-02',
    ],
    "cleanup example backups with default arguments"
);

# %Y-%W has issues, as it splits one Mon-Sun week
# into two Mon-Tue and Wed-Sun weeks
TODO: {
    local $TODO = 'Tue 2024-12-31 and Wed 2025-01-01 are in the same week';
    is_deeply(
        [
            sort keys $db->retention_hash(
                '2024-11-30',    # week 2024-48, Sat
                '2024-12-08',    # week 2024-49, Sun
                '2024-12-15',    # week 2024-50, Sun
                '2024-12-22',    # week 2024-51, Sun
                '2024-12-28',    # week 2024-52, Sat
                '2024-12-29',    # week 2024-52, Sun
                '2024-12-30',    # week 2024-53, Mon
                '2024-12-31',    # week 2024-53, Tue this and the following
                '2025-01-01',    # week 2025-00, Wed should be the same week
                '2025-01-02',    # week 2025-00, Thu
                '2025-01-03',    # week 2025-00, Fri, last daily
                '2025-01-04',    # week 2025-00, Sat
                '2025-01-05',    # week 2025-00, Sun
                '2025-01-06',    # week 2025-01, Mon
                '2025-01-07',    # week 2025-01, Tue
                '2025-01-08',    # week 2025-01, Wed
                '2025-01-09',    # week 2025-01, Thu
            )->%*
        ],
        [
            '2024-11-30',  # monthly 3
            '2024-12-15',  # weekly 5
            '2024-12-22',  # weekly 4
            '2024-12-29',  # weekly 3
            '2024-12-31',  # monthly 2, quarterly 2, yearly 2
            '2025-01-03',  # daily 7
            '2025-01-04',  # daily 6
            '2025-01-05',  # daily 5, weekly 2
            '2025-01-06',  # daily 4
            '2025-01-07',  # daily 3
            '2025-01-08',  # daily 2
            '2025-01-09',  # daily 1, weekly 1, monthly 1, quarterly 1, yearly 1
        ],
        '2024-12-31 and 2025-01-01 should be in the same week'
    );
}

done_testing;
