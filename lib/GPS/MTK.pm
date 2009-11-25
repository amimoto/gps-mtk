package GPS::MTK;

# IO handles the connection to the GPS
# Commands handles the querying/responses from the gps
#   but it uses 
#   Features, which holds the capabilities of the gps 
#   in question
# 

use strict;
use vars qw/ $VERSION $ABSTRACT /;
$VERSION = '0.00';
$ABSTRACT = 'Handles the proprietary extensions on MTK chipset based GPS receivers';
use GPS::MTK::Constants qw/ :commands /;
use GPS::MTK::Utils::NMEA;
use GPS::MTK::Base
    MTK_ATTRIBS => {

        debug              => 1,

# Driver based handling of IO and parsing
        io_class           => 'GPS::MTK::IO::Serial',
        handler_class      => 'GPS::MTK::Handler',
        command_class      => 'GPS::MTK::Command',
        device_class       => 'GPS::MTK::Device::NONMTK',
        decoder_class      => 'GPS::MTK::Decoder::GPX',

# Basic configuration
        io_timeout         => 4,
        io_send_reattempts => 3,
        io_blocking        => 1,

# Some internal variables to track state
        _gps_type          => undef,

# The files users will generally be paying with
        comm_port_fpath    => '',
        track_dump_fpath   => '',
        log_dump_fpath     => '',

# This key will never be used. This is entirely for you to mess with
        my_data            => {},
    };

####################################################
# The core interface functions
####################################################

sub new {
# --------------------------------------------------
# Let's load/init the record
#
    my $self = shift;
    $self = $self->SUPER::new(@_);

# Let's immediately initialize the IO connection
    $self->io_obj;

# Let's ask the GPS what sort it is
    my $gps_info = $self->gps_info;

    return $self;
}

sub connect {
# --------------------------------------------------
# establish a connection to the GPS device and
# along the way figure out what we can do with it
# We only activate the special functions if the
# GPS responds to the MTK identify command
#
    my ( $self ) = @_;

    my $io_obj     = $self->io_obj;

# If we don't know what sort of GPS this is,
# let's ask.
# =========================================================
# We check here to see if we've identified and loaded the
# appropriate driver for the gps
# =========================================================
    GPS_TYPE_TEST: {

# Don't bother testing if we already have performed the
# test.
        $self->{_gps_type} and last;

# =========================================================
# If we get here, we haven't identified the GPS yet. Let's
# see if we can figure it out
# =========================================================
        MTK_CHECK: {
# Only if this unit is a MTK type that responds to the
# test sequence do we continue on
            $self->gps_send_wait(PMTK_TEST,PMTK_ACK) or last;

# TODO: Returns a weird message back. handle later
#        $self->gps_send_wait(PMTK_Q_VERSION,PMTK_DT_VERSION);
            $self->gps_send_wait(PMTK_Q_RELEASE,PMTK_DT_RELEASE) or last;

# Okay, we know that this is an MTK based device. Let's load up the 
# proper driver for this device
            $self->{_gps_type} = 'MTK';

        } # /MTK_CHECK

        $self->{_gps_type} ||= 'NONMTK';

# Only change the driver if we recognize it's the default one
        if ( $self->{device_class} eq $MTK_ATTRIBS->{device_class} ) {
            require GPS::MTK::Device;
            $self->{device_class} = GPS::MTK::Device->device_class_identify(
                                        $self->gps_metadata,
                                        $self->gps_state
                                    );
            delete $self->{device_obj};
        };

# =========================================================
# Getting here, this means we now know what sort of GPS
# We're dealing with. We now load the data from the
# driver so that we can customize the behaviour of GPS::MTK
# =========================================================
        my $device_obj   = $self->device_obj;
        my $device_specs = $device_obj->device_specs;
        my $command_obj  = $self->command_obj or return;
        $command_obj->{commands} = {%{$device_specs->{commands}}};

    } # /GPS_TYPE_TEST

# We're connected and good? Awesome.
    return 1;
}

sub connected {
# --------------------------------------------------
# True if the port is still open. It's a dirty way
# of handling it but if the io_obj isn't there, 
# we assume that the port is closed.
#
    my ( $self ) = @_;
    return $self->{io_obj} ? 1 : 0;
}

sub logger_state {
# --------------------------------------------------
# Fetches the logger state from the GPS
#
    my $self = shift;
    my $logger_state;
    FETCH_META: {
        $self->gps_send_wait(PMTK_LOG_QUERY_FORMAT,            PMTK_LOGGER_RESPONSE) or last;
        $self->gps_send_wait(PMTK_LOG_QUERY_TIME_INTERVAL,     PMTK_LOGGER_RESPONSE) or last;
        $self->gps_send_wait(PMTK_LOG_QUERY_DISTANCE_INTERVAL, PMTK_LOGGER_RESPONSE) or last;
        $self->gps_send_wait(PMTK_LOG_QUERY_SPEED_INTERVAL,    PMTK_LOGGER_RESPONSE) or last;
        $self->gps_send_wait(PMTK_LOG_QUERY_RECORDING_METHOD,  PMTK_LOGGER_RESPONSE) or last;
        $self->gps_send_wait(PMTK_LOG_QUERY_STATUS,            PMTK_LOGGER_RESPONSE) or last;
        $self->gps_send_wait(PMTK_LOG_QUERY_MEMORY,            PMTK_LOGGER_RESPONSE) or last;
        $self->gps_send_wait(PMTK_LOG_QUERY_POINTS,            PMTK_LOGGER_RESPONSE) or last;
        my $metadata = $self->gps_metadata;
        $logger_state = $metadata->{logger};
    };
    return $logger_state;
}

sub logger_download {
# --------------------------------------------------
# Downloads all the data on the GPS
#
# Options that can be provided to this function are:
#
# progress => sub {
#                    my ( $self, $percent_complete ) = @_;
#                 }
#
#
    my ( $self, $opts ) = @_;

# Base variable prep
    $opts ||= {};
    my $progress_sub = $opts->{progress} || sub {};
    my $handler_obj  = $self->handler_obj;

# We'll need information on the logger (undef is no logger on device)
    my $logger_state = $self->logger_state or return;

# Get information on the device
    my $device_obj   = $self->device_obj;
    my $device_specs = $device_obj->device_specs;
    my $logger_specs = $device_specs->{logger} or return;

# That will allow us to guessestimate how many blocks of
# data we need to download
    my $mem_index      = 0;
    my $mem_chunk_size = $logger_specs->{chunk_size};
    my $mem_used       = $logger_state->{memory_used};

# We load a handler onto the PMTK so we can intercept the data
#    my $hook_id = $handler_obj->event_hook();

# Start downloading! :)
    while ( $mem_index < $mem_used ) {

# Let's get the amount of memory left (or the portion thereof, up to
# $mem_chunk_size)
        my $mem_chunk = $mem_used - $mem_index;
        if ( $mem_chunk > $mem_chunk_size ) { $mem_chunk = $mem_chunk_size };

# This sends the actual request
        $self->gps_send(PMTK_LOG_REQ_DATA,$mem_index,$mem_chunk_size) or die "FIXME: Request failed. Oops";
        $self->gps_wait(sub {
        # --------------------------------------------------
        # We will manually trap the events and parse the
        # incoming binary data
        #
            my ($line,$self,$code) = @_;
# So we're trying to parse the data as we get it.
            return $line =~ /PMTK001,182,7,3/;
        },{io_timeout=>0});

# Increment the counter
        $mem_index += $mem_chunk;
    }

# At this point, we should have the binary data in the 
# logger's metadata field. Awesome. Let's parse it 
# into something we can use.
    my $metadata = $self->gps_metadata;
    my $logger_state = $metadata->{logger};

    my $decoder_obj = $self->decode_obj;
    my $parsed = $decoder_obj->parse( $logger_state->{data}, $opts );

    return { 
        binary => $logger_state->{data},
        parsed => $parsed,
    };
}

sub logger_erase {
# --------------------------------------------------
# Wipe out all the data on the GPS
#
    my $self = shift;
}

sub loop {
# --------------------------------------------------
# Run a single loop through the event loop. If we 
# setup the object via blocking, we will wait until
# an event is encountered
#
    my ( $self ) = @_;
    my $io_obj = $self->io_obj or return;

# We need to propate down the blocking setting...
    $io_obj->blocking($self->{blocking});
    my $l = $io_obj->line_get or return;
    $self->{debug} and warn $l;

# Log the nmea string
    $self->nmea_string_log($l);

# We have a line, let's act upon it.
    my $handler_obj = $self->handler_obj or return;
    return $handler_obj->handle($l);
}

sub blocking {
# --------------------------------------------------
# Set whether or not the system will wait for every
# line that the GPS sends or simply handle things
# when the opportunity is given to it.
#
    my $self = shift;
    return ( $self->{blocking} = @_ ? shift : 1 );
}

####################################################
# GPS Commands
####################################################

sub gps_info {
# --------------------------------------------------
# Let's see if we can identify the unit that 
# we're connected with
#
    my ( $self ) = @_;

# Get the connections and the event handler
    my $io_obj = $self->io_obj           or return;
    my $handler_obj = $self->handler_obj or return;
    
# We will make this temporarily blocking while 
# we try and figure out what sort of gps this is.

}

sub gps_send {
# --------------------------------------------------
# sends a single query to the GPS
#
    my ( $self, @elements ) = @_;

    if ( @elements == 1 ) {
        if ( ref $elements[0] ) { 
            @elements = @{$elements[0]};
        }
        else {
            @elements = split( /,/, $elements[0] ); 
        }
    }
    my $command_obj = $self->command_obj or return;
    my $handler_obj = $self->handler_obj or return;
    my $code        = shift @elements;
    my $nmea_string = $command_obj->command_string(uc($code), @elements);
    $self->{debug} and print "S:$nmea_string\n";

    $self->nmea_string_log( "SEND: $nmea_string" );
    my $io_obj      = $self->io_obj or return;
    return $io_obj->line_put($nmea_string) or die $!;
}

sub gps_wait {
# --------------------------------------------------
# This will block until the requested code is found
#
    my ( $self, $code_wait, $opts ) = @_;

# Basic variable prep
    $opts ||= {};
    my $command_obj = $self->command_obj or return;
    my $handler_obj = $self->handler_obj or return;
    my $io_obj      = $self->io_obj or return;

# Make sure we're testing on the UC version of the key...
    unless ( ref $code_wait ) {
        $code_wait = $command_obj->command_signature($code_wait) || uc($code_wait);
    }
    my $line;

    $io_obj->blocking(1);
    my $start_tics = time;
    my $end_tics   = defined $opts->{io_timeout} ? $opts->{io_timeout} : 
                             $self->{io_timeout} ? $self->{io_timeout} : 0;
    $end_tics += time if $end_tics;

    while (1) {
        $line = $io_obj->line_get;
        defined $line or last;
        $line =~ s/[\n\r]*$//;
        $line or next;

# If there is an event, we just send it to the event 
# engine as required.
        $self->nmea_string_log($line);
        $handler_obj->handle($line);

# Now check to see if the event matches our wait code
        my @e = split /,/, $line;
        my $code = shift @e;
        $code =~ s/^\$//;
        my $cmp_line = $line;
        $cmp_line =~ s/^\$//;
        if ( ref $code_wait ? $code_wait->($line,$self,$code)
                            : $cmp_line =~ /$code_wait/
        ) {
            last;
        };

# Doesn't match. Let's just see if we've gone past the io timeout wait
        if ( $end_tics and time >= $end_tics ) {
            return;
        }

    };

    return 1;
}

sub gps_send_wait {
# --------------------------------------------------
# This will send a string to the GPS then wait for 
# for a particular code and trigger the appropriate
# callback if defined
#
    my ( $self, $elements, $code_wait ) = @_;

# Basic variable prep
    my $command_obj = $self->command_obj or return;
    my $handler_obj = $self->handler_obj or return;

    my $reattempts = $self->{io_send_reattempts} || 0; 
    while (1) {
        $self->gps_send( $elements );
        $self->gps_wait( $code_wait ) and last;

# Retry if we failed. gps_wait is only true if we managed to wait
# successfully for the wait code
        if ( $reattempts-- ) {
            next;
        }
        else {
            die "Could not receive response <$code_wait> desired";
        }
    };
    return 1;
}

####################################################
# State functions
####################################################


sub is_mtk {
# --------------------------------------------------
# Returns true if the device is an MTK based device
#
    my ( $self ) = @_;
    $self->connect;
    return $self->{_gps_type} eq 'MTK';
}

sub is_mtk_logger {
# --------------------------------------------------
# Returns true if the device is an MTK based logging
# device.
#
    my ( $self ) = @_;
    $self->connect;
    my $device_obj = $self->device_obj or return;
    my $specs = $device_obj->specs     or return;
    return $specs->{logger};
}

sub gps_state {
# --------------------------------------------------
    my $self = shift;
    my $handler_obj = $self->handler_obj;
    return $handler_obj->{state};
}


sub gps_metadata {
# --------------------------------------------------
    my $self = shift;
    my $handler_obj = $self->handler_obj;
    return $handler_obj->{metadata};
}


####################################################
# Object instantiation code
####################################################

sub io_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{io_obj} ||= do {
        my $io_class = $self->{io_class};
        return unless $io_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $io_class";
        my $io_obj = $io_class->new($self);
        $io_obj->connect;
        $io_obj;
    };
}

sub handler_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{handler_obj} ||= do {
        my $handler_class = $self->{handler_class};
        return unless $handler_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $handler_class; 1" or die $@;
        my $handler_obj = $handler_class->new($self);
        $handler_obj;
    };
}


sub command_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{command_obj} ||= do {
        my $command_class = $self->{command_class};
        return unless $command_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $command_class";
        my $command_obj = $command_class->new($self);
        $command_obj;
    };
}

sub device_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{device_obj} ||= do {
        my $device_class = $self->{device_class};
        return unless $device_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $device_class; 1" or die $@;
        my $device_obj = $device_class->new($self);
        $device_obj;
    };
}


sub decoder_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{decoder_obj} ||= do {
        my $decoder_class = $self->{decoder_class};
        return unless $decoder_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $decoder_class; 1" or die $@;
        my $decoder_obj = $decoder_class->new($self);
        $decoder_obj;
    };
}

sub nmea_string_log {
# --------------------------------------------------
# Log a single NMEA string to the output file
#
    my ( $self, $line ) = @_;
    return unless $self->{log_dump_fpath};
    require Symbol;
    my $fh = Symbol::gensym();
    open $fh, ">>$self->{log_dump_fpath}" or die $!;
    print $fh "$line\n";
    close $fh;
}

1;


