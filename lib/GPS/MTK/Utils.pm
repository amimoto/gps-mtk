package GPS::MTK::Utils;

use strict;
use Math::Trig;

use GPS::MTK::Constants qw/ :constants /;
use GPS::MTK::Base
    MTK_ATTRIBS => {
    };

sub distance {
# --------------------------------------------------
# Returns the distance between two coordinates, in meters
# Uses the great-circle equation
#
    my ( $lat_a, $lon_a, $lat_b, $lon_b ) = map {$_*RADIANS_IN_DEGREE} @_;

    my $a = sin(($lat_b-$lat_a)/2.0);
    my $b = sin(($lon_b-$lon_a)/2.0);
    my $h = $a**2 + cos($lat_a) * cos($lat_b) * $b**2;
    my $distance = 2 * asin(sqrt($h)) * EARTH_RADIUS; # distance in meters

    return $distance;
}

1;


