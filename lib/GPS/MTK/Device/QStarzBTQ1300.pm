package GPS::MTK::Device::QStarzBTQ1300;

use strict;
use GPS::MTK::Constants qw/ $COMMAND_DEFINITIONS /;
use GPS::MTK::Device
    ISA => 'GPS::MTK::Device',
    MTK_ATTRIBS => {
        specs => {
            name     => 'QStarz BT-Q1300 Sports Recorder', # The device name if available
            logger   => {
                        memory => 2097152,    # logger bytes
                        chunk_size => 0x10000, # download chunk size
            },
            commands => {map {($_=>'')} keys %$COMMAND_DEFINITIONS},
        }
    };

1;

