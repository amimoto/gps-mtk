package GPS::MTK::Utils::NMEA;

use strict;

sub envelope_wrap {
# --------------------------------------------------
# This will take a base NMEA string and create the
# appropriate delivery envelope (wrapped with "$"
# and the checksum)
#
    my $pkg = shift;
    my $line = join ",", @_;
    my $checksum = $pkg->checksum_calc($line);
    return '$' . $line . "*" . $checksum;
}

sub checksum_calc {
# --------------------------------------------------
    my ( $pkg, $nmea ) = @_;

# Pull out the portion of the string that will be used for
# checksum calculation
    $nmea =~ s/^\$?([^\*]+)(\*\w\w)?$/$1/ or return;

# Now calculate the checksum
    my $chk = 0;
    $chk ^= ord($_) for (split //,$nmea);

# Checksum is a 2 digit hex number
    $chk = sprintf '%02x', $chk;

# Done!
    return uc $chk;
}

sub dms_to_decimal {
# --------------------------------------------------
    my ( $pkg, $dms, $direction ) = @_;
    my $dms_str = sprintf( "%05.05f", $dms );
    my ( $d, $m ) = $dms_str =~ /(\d+)(\d\d\.\d+)/;
    my $degrees = $d + $m * 60/3600;
    if ( $direction eq 'W' or $direction eq 'S' ) {
       $degrees *= -1;
    }
    return sprintf("%.06f",$degrees);
}


1;
