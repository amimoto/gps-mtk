package GPS::MTK::Device::MTK;

# Generic MTK handler class

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        specs => {
            name   => 'MTK Generic', # The device name if available
            logger => 1,             # has a logger
            memory => '2097152',     # logger bytes
        },
    };

1;
