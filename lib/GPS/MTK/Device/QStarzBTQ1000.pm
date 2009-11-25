package GPS::MTK::Device::QStarzBTQ1000;

use strict;
use GPS::MTK::Constants qw/ $COMMAND_DEFINITIONS /;
use GPS::MTK::Device
    ISA => 'GPS::MTK::Device',
    MTK_ATTRIBS => {
        specs => {
            name     => 'QStarz BT-Q1000 Travel Recorder', # The device name if available
            logger   => {
                        memory => 2097152,    # logger bytes
                        chunk_size => 2097152, # download chunk size
            },
            commands => {map {($_=>'')} keys %$COMMAND_DEFINITIONS},
        }
    };

1;

