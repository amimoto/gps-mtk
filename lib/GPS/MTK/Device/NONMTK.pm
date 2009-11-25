package GPS::MTK::Device::NONMTK;

# Generic NMEA GPS handler class 
# We kind of use the default values from the device 
# since the prototype allows only enough commands to
# test if the device is MTK based, or not.

use strict;
use GPS::MTK::Device
    ISA => 'GPS::MTK::Device';

1;
