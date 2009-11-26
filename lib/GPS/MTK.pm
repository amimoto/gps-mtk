package GPS::MTK;

# IO handles the connection to the GPS
# Commands handles the querying/responses from the gps
#   but it uses 
#   Features, which holds the capabilities of the gps 
#   in question
# 

use strict;
use vars qw/ $VERSION $ABSTRACT /;
$VERSION = '0.01';
$ABSTRACT = 'Handles the proprietary extensions on MTK chipset based GPS receivers';
use GPS::MTK::Constants qw/ :commands /;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        device_class => 'GPS::MTK::Device::NONMTK',
    };

sub connect {
# --------------------------------------------------
# establish a connection to the GPS device and
# along the way figure out what we can do with it
# We only activate the special functions if the
# GPS responds to the MTK identify command
#
    my $self = shift;
    ref $self or $self = $self->new;

# Pass along all instantiation variables to device loader
    my $device_obj = $self->object_load($self->{device_class},@_);

# =========================================================
# We haven't identified the GPS yet. Let's see if we can figure it out
# =========================================================
    MTK_CHECK: {
# Only if this unit is a MTK type that responds to the
# test sequence do we continue on
        $device_obj->gps_send_wait(PMTK_TEST,PMTK_ACK) or last;

# TODO: Returns a weird message back. handle later
#        $self->gps_send_wait(PMTK_Q_VERSION,PMTK_DT_VERSION);
        $device_obj->gps_send_wait(PMTK_Q_RELEASE,PMTK_DT_RELEASE) or last;

# Figure out what subclass we wish to use for the device loading
        my $device_class_new = $device_obj->device_class_identify(
                                    $device_obj->gps_metadata,
                                    $device_obj->gps_state
                                );

# Do some magic here. Instead of creating a new object, we simply rebless
# the the device object into the proper object type. This does cause
# problems with initialization code... however, this means we won't throw
# away our existing objects such as the IO connection
        eval "require $device_class_new; 1" or die $@;
        $device_obj = $device_class_new->device_retarget($device_obj => @_) or return;

    } # /MTK_CHECK

# Okay, we should now be connected. W00t.
    return $device_obj;
}

1;


