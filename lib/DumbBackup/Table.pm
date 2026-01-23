package DumbBackup::Table;
use 5.024;
use warnings;
use utf8;

use Exporter qw( import );
use List::Util qw( max sum );

use experimental 'signatures';

our @EXPORT_OK = qw(
  table_for
);

# assuming all rows have the same number of cells
sub table_for ( @rows ) {
    my @cell_width = (0) x $rows[0]->@*;
    for my $row (@rows) {
        $cell_width[$_] = max( $cell_width[$_], length( $row->[$_] ) )
          for 0 .. $#$row;
    }
    my $table = join( '┬', map '─' x ( $_ + 2 ), @cell_width ) . "\n";
    for my $row (@rows) {
        $table .= ' '
          . join( ' │ ',
            map sprintf( "%-$cell_width[$_]s", $row->[$_] ),
            0 .. $#$row )
          . " \n";
    }
    return $table;
}

1;
