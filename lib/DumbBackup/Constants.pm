package DumbBackup::Constants;
use 5.024;
use warnings;

use Exporter 'import';

our @EXPORT_OK = qw(
    BACKUP_RX
);

use constant BACKUP_RX => qr{
    (?:\A|/)                            # beginning of string / basename
    \b([0-9]{4})-([0-9]{2})-([0-9]{2})  # YYYY-MM-DD
    (?:_+                               # underscore(s)
       ([0-9]{2})-([0-9]{2})-([0-9]{2}) # hh-mm-ss
    )?                                  # (optional)
    \z                                  # end of string
}x;

1;
