use Test2::V0;
use DumbBackup::Table qw( table_for );
use utf8;

is(
    table_for(
        [qw( a bb ccc dddd )],
        [qw( aa b cccc dd )],

    ),
    <<~ 'TABLE', 'basic table'
    ────┬────┬──────┬──────
     a  │ bb │ ccc  │ dddd 
     aa │ b  │ cccc │ dd   
    TABLE
);

is(
    table_for(
        [qw( a bb ccc dddd )],
        [qw( aaa bbb ccc ddd )],
        [qw( aaaa bbb cc d )],

    ),
    <<~ 'TABLE', 'another basic table'
    ──────┬─────┬─────┬──────
     a    │ bb  │ ccc │ dddd 
     aaa  │ bbb │ ccc │ ddd  
     aaaa │ bbb │ cc  │ d    
    TABLE
);

done_testing;
