package GPS::MTK::IO;

use strict;

sub connect {
# --------------------------------------------------
# This should return a true value if the connection
# was successful
#
    my ( $self, $source, $opts ) = @_;
    return;
}

sub close {
# --------------------------------------------------
# Close the connection to the socket. 
#
    my ( $self ) = @_;
    return;
}
*release = \*close;


1;
