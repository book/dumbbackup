use Test2::V0;
use DumbBackup::Table qw( table_for );
use utf8;

is(
    table_for( [qw( a bb ccc dddd )], [qw( aa b cccc dd )], ),
    <<~ 'TABLE', 'basic table'
    ────┬────┬──────┬──────
     a  │ bb │ ccc  │ dddd 
     aa │ b  │ cccc │ dd   
    TABLE
);

is(
    table_for(
        [qw( a bb ccc dddd )], [qw( aaa bbb ccc ddd )],
        [qw( aaaa bbb cc d )],
    ),
    <<~ 'TABLE', 'another basic table'
    ──────┬─────┬─────┬──────
     a    │ bb  │ ccc │ dddd 
     aaa  │ bbb │ ccc │ ddd  
     aaaa │ bbb │ cc  │ d    
    TABLE
);

is(
    table_for(
        'short header', [qw( A B C D )],
        '-',            [qw( aa bb ccc dd )],
        [qw( a  bb c ddd )],
    ),
    <<~ 'TABLE', 'table with header and separator'
      short header        
     ────┬────┬─────┬─────
      A  │ B  │ C   │ D   
     ────┼────┼─────┼─────
      aa │ bb │ ccc │ dd  
      a  │ bb │ c   │ ddd 
     TABLE
);

is(
    table_for(
        'a very very long header', [qw( A B C D )],
        '-',                       [qw( aa bb ccc dd )],
        '-',                       [qw( a  bb c ddd )],
    ),
    <<~ 'TABLE', 'table with long header and separators'
      a very very long header 
     ────┬────┬─────┬─────────
      A  │ B  │ C   │ D       
     ────┼────┼─────┼─────────
      aa │ bb │ ccc │ dd      
     ────┼────┼─────┼─────────
      a  │ bb │ c   │ ddd     
     TABLE
);

done_testing;
