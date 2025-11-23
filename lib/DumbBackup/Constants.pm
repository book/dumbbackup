package DumbBackup::Constants;
use 5.024;
use warnings;

use Exporter 'import';

our @EXPORT_OK = qw(
    BACKUP_RX
    BACKUP_RX_CAPTURES
    @PERIODS
);

use constant BACKUP_RX => qr{
    (?:\A|/)                            # beginning of string / basename
    [0-9]{4}-[0-9]{2}-[0-9]{2}          # YYYY-MM-DD
    (?:_                                # underscore
       [0-9]{2}-[0-9]{2}-[0-9]{2}       # hh-mm-ss
    )?                                  # (optional)
    \z                                  # end of string
}x;

use constant BACKUP_RX_CAPTURES => qr{
    (?:\A|/)                            # beginning of string / basename
    ([0-9]{4})-([0-9]{2})-([0-9]{2})    # YYYY-MM-DD
    (?:_                                # underscore
       ([0-9]{2})-([0-9]{2})-([0-9]{2}) # hh-mm-ss
    )?                                  # (optional)
    \z                                  # end of string
}x;

our @PERIODS = qw( days weeks months quarters years );

1;
