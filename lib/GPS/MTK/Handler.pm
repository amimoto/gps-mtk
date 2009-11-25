package GPS::MTK::Handler;

use strict;

use Time::Local;
use GPS::MTK::Constants qw/ :all /;
use GPS::MTK::Utils::NMEA;
use GPS::MTK::Base 
    MTK_ATTRIBS => {
        state            => {},
        metadata         => {},
        checksum_level   => NMEA_CHECKSUM_STRICT,
        event_hook_count => 0,
        event_hooks      => {},
        debug            => 0,
    };

sub handle {
# --------------------------------------------------
# Receives a single NMEA string for parsing
#
    my ( $self, $line, $event_args ) = @_;

# Strip off chars that we don't want to deal with. ie.
# the $ that starts the line and newlines characters
    $line =~ s/(^\$|\n|\r)//g;

# Handle the checksum. Complicated here since we allow a customizable
# level of strictness
    my $chk_level = $self->{checksum_level};
    $line =~ s/\*([0-9a-fA-F]{2})//i or return; my $chk = $+;
    if ( $chk_level != NMEA_CHECKSUM_IGNORE ) {

        my $chk_str = GPS::MTK::Utils::NMEA->checksum_calc( $line );

# If $chk is defined, we only check if required
        if ( $chk ) {
            if ( $chk ne $chk_str 
                and ( $chk_level == NMEA_CHECKSUM_STRICT
                      or $chk_level == NMEA_CHECKSUM_IF_PRESENT )
            ) { # and the checksum doesn't calc...
                return;
            }
        }

# if $chk is not defined
        elsif ( $chk_level == NMEA_CHECKSUM_PRESENCE or $chk_level == NMEA_CHECKSUM_STRICT
        ) {
            return;
        }
    }

# Okay, the checksum is okay, let's start figuring out what the string is meaning
    my @e = split /,/, $line;

# At this point, we want to pass off the action to the appropriate
# handler.
    @e or return;
    my $verb = lc shift @e;
    $self->dispatch($verb,@e);

# At this point we can handle user-events
# While we should "probably" allow the user to override
# certain types of events or correct values before this point
# I'm going to use the worse-is-better principle and just
# get this working :) if enough people yell at me, I'll
# fix it with pre-hooks
# FUNCTION INVOCATION FORMAT:
# function->(
#           $event_args,
#           $verb,
#           $args:arrayref,
#           $self
#      ) 
#
    my $event_hooks = $self->{event_hooks};
    for my $hook_key (keys %$event_hooks) {
        my $hook  = $event_hooks->{$hook_key};
        my $match = $hook->{match};
        if ( ref $match eq 'CODE' ) {
            $match->($verb,\@e,$self,$hook_key) and do {
                $hook->{action}($event_args,$verb,\@e,$self,$hook_key);
            };
        }
        elsif ( ref $match eq 'Regex' ) {
            $verb =~ $match and do {
                $hook->{action}($event_args,$verb,\@e,$self,$hook_key);
            };
        }
        elsif ( not ref $match ) {
            $verb =~ /$match/ and do {
                $hook->{action}($event_args,$verb,\@e,$self,$hook_key);
            };
        }
        else { next } # not matched
    }

}

sub dispatch {
# --------------------------------------------------
# We will now handle the parsed nmea string
#
    my $self = shift;
    my $verb = uc(shift||'') or return;
    my @args = @_;

    $self->{debug} and print "R:".join(",",$verb,@args)."\n";

# GPGGA : Fixed Data
    my $state = $self->state;
    if ( $verb eq 'GPGGA' ) {
        my @keys = qw( utc lat lat_dir lon lon_dir fix sats hdop alt units age station  );
        @$state{@keys} = @args;
        $state->{lat} = GPS::MTK::Utils::NMEA->dms_to_decimal( $state->{lat}, delete $state->{lat_dir} );
        $state->{lon} = GPS::MTK::Utils::NMEA->dms_to_decimal( $state->{lon}, delete $state->{lon_dir} );
    }

# GPRMC : Recommended Minimum 
    elsif ( $verb eq 'GPRMC' ) {
        my @keys = qw( utc status lat lat_dir lon lon_dir speed heading date mag_var mag_var_dir );
        @$state{@keys} = @args;
        $state->{lat} = GPS::MTK::Utils::NMEA->dms_to_decimal( $state->{lat}, delete $state->{lat_dir} );
        $state->{lon} = GPS::MTK::Utils::NMEA->dms_to_decimal( $state->{lon}, delete $state->{lon_dir} );

        my @t = ( $state->{utc} =~ /(\d\d)(\d\d)(\d\d)(\.\d+)?/ );
        my @d = $state->{date} =~ /(\d\d)(\d\d)(\d\d)/; # in ddmmyy format
        unshift @d, reverse( @t[0,1,2] );
        $d[4]--;
        my $subseconds = $t[4] || 0;
        $state->{unixtime} = timegm(@d) + $subseconds;
    }

# GPGSA : Degree of Precision and active satellites
    elsif ( $verb eq 'GPGSA' ) {
        my @keys = qw( sat_mode sat_fix sat_prn_number sat_dop sat_hdop sat_vhdop  );
        @$state{@keys} = @args;
    }

# GPZDA : Time/Date
    elsif ( $verb eq 'GPZDA' ) {
        my @keys = qw( hhmmss day month year local_hours local_minutes );
        @$state{@keys} = @args;

        my @t = ( $state->{utc} =~ /(\d\d)(\d\d)(\d\d)(\.\d+)?/ );
        my $subseconds = $t[4] || 0;
        $state->{unixtime} = timegm(
                                reverse(@t[0,1,2]), 
                                @$state{qw( year month day )}
                            ) + $subseconds;
    }

# GPGSV : Satelites in view
    elsif ( $verb eq 'GPGSV' ) {
        my ( $line_count, $line_num, $sat_num, @sat_data ) = @_;
        if ( $line_num == 1 ) {
            $state->{satellites_new} = [];
        }

        my $sats = $state->{satellites_new};
        my @sat_keys = qw( sat_prn sat_elevation sat_azimuth sat_snr );
        while ( @sat_data ) {
            my $rec = {};
            @$rec{@sat_keys} = splice @sat_data, 0, 4;
            next unless $rec->{sat_prn};
            push @$sats, $rec;
        }

        if ( $line_num == $line_count ) {
            $state->{satellites} = $sats;
            delete $state->{satellites_new};
        }
    }

# GPVTG : Velocity Made Good
    elsif ( $verb eq 'GPVTG' ) {
        my @keys = qw( true_deg junk mag_deg junk speed_knots junk speed_kmh );
        @$state{@keys} = @args;
        delete $state->{junk};
    }

# GPMSS : Receiver status
    elsif ( $verb eq 'GPMSS' ) {
        my @keys = qw( beacon_strength beacon_noise beacon_freq beacon_bps  );
        @$state{@keys} = @args;
    }

# Handle PMTK strings
    elsif ( $verb =~ /^PMTK\d+/ ) {
        $self->handle_pmtk( $verb => @args );
    }

# UNKNOWN STRING! We only do somethign with it if we have debug turned on
    else {
        $self->handle_unknown( $verb => @args );
    }

    return 1; # we assume succcess. asserts are for weenies!
}

sub handle_pmtk {
# --------------------------------------------------
# Hande the MTK specific data fields
#
    my ( $self, $verb, @args ) = @_;

# Figure out which pmtk handler this needs to be
    $verb =~ /^PMTK(\d+)/ or return;
    my $cmd_id = $1;

    my $metadata = $self->{metadata} ||= {};

# Okay, now we start playing! :)
    if ( 0 ) {
    }

# PMTK_DT_VERSION
    elsif ( $cmd_id == 704 ) {
    }

# PMTK_DT_RELEASE - MTK firmware data information
    elsif ( $cmd_id == 705 ) {
        $metadata->{release_string} = $args[0];
        $metadata->{model_id}       = $args[1];
    }

# PMTK_LOGGER_RESPONSE - When we're getting information about
#                        the logger's state
    elsif ( $cmd_id == 182 and $args[0] == 3 ) {
        $self->handle_pmtk_log($verb,@args);
    }

# PMTK_LOGGER_DATA - When we're downloading log data
    elsif ( $cmd_id == 182 and $args[0] == 8 ) {
        $self->handle_pmtk_log_data($verb,@args);
    }



}

sub handle_pmtk_log {
# --------------------------------------------------
# Handles MTK logger actions
#
    my ( $self, $verb, @args ) = @_;
    my $metadata = $self->{metadata} ||= {};
    shift @args; # get rid of the "3"
    my $type = shift @args; # figure out what sort of update

    if ( 0 ) {
    }

# Logger Query Format
    elsif ( $type == 2 ) {
        $metadata->{logger}{format} = $args[0];
    }

# Logger Time Interval
    elsif ( $type == 3 ) {
        $metadata->{logger}{time_interval} = $args[0];
    }

# Logger Distance Interval
    elsif ( $type == 4 ) {
        $metadata->{logger}{distance_interval} = $args[0];
    }

# Logger Speed Interval
    elsif ( $type == 5 ) {
        $metadata->{logger}{speed_interval} = $args[0];
    }

# Logger Recording Method
    elsif ( $type == 6 ) {
        $metadata->{logger}{status} = $args[0];
    }

# Logger Status
    elsif ( $type == 7 ) {
        $metadata->{logger}{status} = $args[0];
    }

# Memory used
    elsif ( $type == 8 ) {
        $metadata->{logger}{memory_used} = hex($args[0]);
        $metadata->{logger}{data}        = \("\0" x hex($args[0]));
    }

# Trackpoints
    elsif ( $type == 10 ) {
        $metadata->{logger}{points_used} = hex($args[0]);
    }

}

sub handle_pmtk_log_data {
# --------------------------------------------------
# This is not the same thing as log stat information.
# This is used for the download of the binary log 
# information
#
    my ( $self, $verb, @args ) = @_;

# Variable prep
    shift @args; # get rid of the "8"
    my ( $memory_offset_hex, $data_hex ) = @args; 
    my $memory_offset = hex $memory_offset_hex;
    my $data          = pack "H*", $data_hex;
    my $metadata      = $self->{metadata}{logger} ||= {};
    my $logger_data   = $metadata->{data};
    $$logger_data   ||= '';

# What we're now going to do is add the new string of data into
# our memory buffer. So we can just slot in the read data as
# it comes in, in any order yet have it come out in the proper
# order. w00tw00t
    my $data_len = length $$logger_data;
    my $target_len = $memory_offset + length $data;
    if ( $data_len < $target_len ) {
        $$logger_data .= "\0" x ( $target_len - $data_len );
    }
    substr $$logger_data, $memory_offset, length $data, $data;

# TODO: since data isn't coming in incredibly fast, we should be
# able to do parsing of the data as we go. However, that'll be for
# later... mostly I'm not doing this for now since it requires
# buffered reads from within the code. Ick.

    return 1;
}

sub handle_unknown {
# --------------------------------------------------
    my ( $self, $verb, @args ) = @_;
}

sub event_hook {
# --------------------------------------------------
# We need to put this hook into the chain that will be
# checked when the system recieves a string.
# The $match can be either 
# 1. string or 
# 2. a function->($event_args,$verb,$args:arrayref,$self) that returns a true value 
# When a match is found, $action->($verb,$args:arrayref,$self,$hook_id) 
# is called
#
#
    my ( $self, $match, $action ) = @_;
    my $hook_id = $self->{event_hook_count}++;
    $self->{event_hooks}{$hook_id} = {
        match  => $match,
        action => $action
    };
    return $hook_id;
}

sub event_unhook {
# --------------------------------------------------
# Removes an event hook from executing... again...
# ever. how final.
#
    my ( $self, $hook_id ) = @_;
    delete $self->{event_hooks}{$hook_id};
}

sub state {
# --------------------------------------------------
# Returns the current state of the gps. Note that
# this hash is the internal hash... meaning,
# don't clobber it!! ;)
#
    my $self = shift;
    return $self->{state};
}

1;
