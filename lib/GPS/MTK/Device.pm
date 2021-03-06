package GPS::MTK::Device;

use strict;
use GPS::MTK::Constants qw/ $DEBUG :commands /;
use GPS::MTK::Utils::NMEA;
use GPS::MTK::Base
    MTK_ATTRIBS => {

# Override to handle the individual parameters for the GPS
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

# Driver based handling of IO and parsing
        io_class           => 'GPS::MTK::IO::Serial',
        handler_class      => 'GPS::MTK::Handler',
        command_class      => 'GPS::MTK::Command',
        decoder_class      => 'GPS::MTK::Decoder::GPX',

# Basic configuration
        io_timeout         => 4,
        io_send_reattempts => 3,
        io_blocking        => 1,

# Initialization actions
        probe_skip         => 0,

# Some internal variables to track state
        _gps_type          => 'NONMTK',

# The files users will generally be paying with
        comm_port_fpath    => '',
        track_dump_fpath   => '',
        log_dump_fpath     => '',

# This key will never be used. This is entirely for you to mess with
        my_data            => {},
    };

sub device_retarget {
# --------------------------------------------------
# This can be used by the submodules to handle 
# the moment where the object is "reblessed" into
# its correct class
#
    my $pkg                 = shift;
    my $device_obj_original = shift;

    my $self = $pkg->new(@_);

    while ( my ( $k, $v ) = each %$device_obj_original ) {

# Import all only fields starting with _ (excepting the command_obj)
        next unless $k =~ /^_/;
        next if     $k =~ /^_(command)/;

        $self->{$k} = $v;
    }

    return $self;
}

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
    my ( $self_pkg, $metadata, $state ) = @_;

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

####################################################
# The core interface functions
####################################################

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
    my $device_specs = $self->device_specs;
    my $logger_specs = $device_specs->{logger} or return;

# That will allow us to guessestimate how many blocks of
# data we need to download
    my $mem_index      = 0;
    my $mem_chunk_size = $logger_specs->{chunk_size};
    my $mem_used       = $logger_state->{memory_used};
    my $mem_limit      = $mem_used > $mem_chunk_size ? $mem_chunk_size  : $mem_used;
    die $mem_limit;

# We load a handler onto the PMTK so we can intercept the data
#    my $hook_id = $handler_obj->event_hook();

# Start downloading! :)
    while ( $mem_index < $mem_used ) {

# Let's get the amount of memory left (or the portion thereof, up to
# $mem_chunk_size)
        my $mem_chunk = $mem_used - $mem_index;
        if ( $mem_chunk > $mem_limit ) { $mem_chunk = $mem_limit };

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
    $logger_state = $metadata->{logger};

    my $decoder_obj = $self->decoder_obj;
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
    $DEBUG and warn $l;

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
    $DEBUG and print "S:$nmea_string\n";

    $self->nmea_string_log( "S:$nmea_string" );
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
            $! = "Could not receive response <$code_wait> desired";
            return;
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
    my $specs = $self->specs     or return;
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


####################################################
# Object instantiation code
####################################################

sub handler_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{_handler_obj} ||= do {
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
    return $self->{_command_obj} ||= do {
        my $command_class = $self->{command_class};
        return unless $command_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $command_class";
        my $command_obj = $command_class->new($self->{specs});
        $command_obj;
    };
}

sub decoder_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{_decoder_obj} ||= do {
        my $decoder_class = $self->{decoder_class};
        return unless $decoder_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $decoder_class; 1" or die $@;
        my $decoder_obj = $decoder_class->new($self);
        $decoder_obj;
    };
}

sub io_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{_io_obj} ||= do {
        my $io_class = $self->{io_class};
        return unless $io_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $io_class";
        my $io_obj = $io_class->new($self);
        $io_obj->connect;
        $io_obj;
    };
}



1;
