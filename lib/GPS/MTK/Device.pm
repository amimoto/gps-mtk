package GPS::MTK::Device;

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        specs => {
            name          => 'Unknown GPS Device', # The device name if available
            logger        => undef,                # has a logger? 
                                                   #  no logger - undef
                                                   #  has logger then hashref of attributes
                                                   #  {
                                                   #    memory     => [bytes of memory],
                                                   #    chunk_size => [download chunk size],
                                                   #  }
            commands => {map {($_=>'')}qw( 
                PMTK_TEST      PMTK_ACK 
                PMTK_Q_RELEASE PMTK_DT_RELEASE 
            )},
        },
    };

sub device_specs {
# --------------------------------------------------
    my $self = shift;
    return $self->{specs};
}

sub device_class_identify {
# --------------------------------------------------
# This will name the proper package based upon the gps 
# information provided
#
    my ( $pkg, $metadata, $state ) = @_;

    my $model_id = uc $metadata->{model_id};

# QStarz Q1000 Bluetooth Logger
    my $pkg = 'GPS::MTK::Device::MTK';
    if ( $model_id eq '001D' ) {
        $pkg = 'GPS::MTK::Device::QStarzBTQ1000';
    }

# QStarz Q1300 Bluetooth Logger
    elsif ( $model_id eq '8805' ) {
        $pkg = 'GPS::MTK::Device::QStarzBTQ1300';
    }

    return $pkg;
}

1;
