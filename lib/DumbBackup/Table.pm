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
sub table_for ( $header, @rows ) {
    my $table;
    if ( ref $header ) {
        unshift @rows, $header;
        $header = '';
    }
    my @cell_width = (0) x $rows[0]->@*;
    for my $row ( grep ref, @rows ) {
        $cell_width[$_] = max( $cell_width[$_], length( $row->[$_] ) )
          for 0 .. $#$row;
    }
    my $table_width = sum( @cell_width - 1, map $_ + 2, @cell_width ) - 2;
    if ( $table_width < length $header ) {
        $cell_width[-1] = $cell_width[-1] + length($header) - $table_width;
        $table_width = length $header;
    }
    $table .= sprintf( " %-${table_width}s \n", $header )
      . join( '┬', map '─' x ( $_ + 2 ), @cell_width ) . "\n"
      if $header;
    for my $row (@rows) {
        if ( ref $row ) {
            $table .= ' '
              . join( ' │ ',
                map sprintf( "%-$cell_width[$_]s", $row->[$_] ),
                0 .. $#$row )
              . " \n";
        }
        else {
            $table .= join( '┼',
                map '─' x ( $cell_width[$_] + 2 ),
                0 .. $rows[0]->$#* )
              . "\n";
        }
    }
    return $table;
}

1;
