package GPS::MTK::Command;

use strict;
use GPS::MTK::Constants qw/ $COMMAND_DEFINITIONS /;
use GPS::MTK::Utils::NMEA;
use GPS::MTK::Utils::Arguments;
use GPS::MTK::Base
    MTK_ATTRIBS => {

# This should hold a reference that contains
# all the commands that are available to the user
            commands => {map {($_=>'')}qw( 
                PMTK_TEST      PMTK_ACK 
                PMTK_Q_RELEASE PMTK_DT_RELEASE 
            )},

    };

sub command_signature {
# --------------------------------------------------
# Attempts to find the proper initial PMTKXXX value
# for the setting requested
#
    my ( $self, $command, @args ) = @_;

# Let's see if the command exists
    my $commands = $self->{commands};
    return unless exists $commands->{$command};

# Now, check the arguments
    my $protos = $commands->{$command};
    unless ( ref $protos ) {
        $protos = $COMMAND_DEFINITIONS->{$command};
    }
    my $arg_obj = $self->arg_obj;
    my $arg_ok = $arg_obj->proto_match(\@args,$protos); 
    if ( not $arg_ok ) { # undef if arguments don't match anything useful
        warn $arg_obj->{error};
        return;
    }

# Now what do we want to do with this this? If it's a ref, we should execute 
# the function
    my $base_nmea = '';
    if ( ref $arg_ok ) {
        my @r = $arg_ok->(@args);
        $base_nmea = ( @r == 1 and ref $r[0] ) ? $r[0] : join ",", @r;
    }

# Is it a soft reference to a function? We assume the function has already 
# been "require FOO::D"
    elsif ( $arg_ok =~ /^\w+(\:\:\w+)+$/ ) {
        no strict 'refs';
        my @r = $arg_ok->(@args);
        $base_nmea = ( @r == 1 and ref $r[0] ) ? $r[0] : join ",", @r;
        use strict 'refs';
    }

# And if it ain't we'll do... uh, something
    elsif ( $arg_ok eq 'MATCHED') {
        $base_nmea = join ",", $command, @args;
    }

# Now that we have the action we want to deal with, let's
# wrap the string and pass it along. If one of the functions
# returns something we should pass on literally, we return it as a
# scalar ref. Then the code will not create a checksum envelope
    return $base_nmea;
}

sub command_string {
# --------------------------------------------------
# Given parameters, attempts to create an outgoing
# command
#
    my ( $self, $command, @args ) = @_;

# Let's see if the command exists
    my $commands = $self->{commands};
    return unless exists $commands->{$command};

# Now, check the arguments
    my $protos = $commands->{$command};
    unless ( ref $protos ) {
        $protos = $COMMAND_DEFINITIONS->{$command};
    }

    my $arg_obj = $self->arg_obj;

    my $arg_ok = $arg_obj->proto_match(\@args,$protos); 

    if ( not $arg_ok ) { # undef if arguments don't match anything useful
        warn $arg_obj->{error};
        return;
    }

# Now what do we want to do with this this? If it's a ref, we should execute 
# the function
    my $base_nmea = '';
    if ( ref $arg_ok ) {
        my @r = $arg_ok->(@args);
        $base_nmea = ( @r == 1 and ref $r[0] ) ? $r[0] : join ",", @r;
    }

# Is it a soft reference to a function? We assume the function has already 
# been "require FOO::D"
    elsif ( $arg_ok =~ /^\w+(\:\:\w+)+$/ ) {
        no strict 'refs';
        my @r = $arg_ok->(@args);
        $base_nmea = ( @r == 1 and ref $r[0] ) ? $r[0] : join ",", @r;
        use strict 'refs';
    }

# And if it ain't we'll do... uh, something
    elsif ( $arg_ok eq 'MATCHED') {
        $base_nmea = join ",", $command, @args;
    }

# Now that we have the action we want to deal with, let's
# wrap the string and pass it along. If one of the functions
# returns something we should pass on literally, we return it as a
# scalar ref. Then the code will not create a checksum envelope
    $base_nmea or return;
    my $line = ref $base_nmea ? $$base_nmea 
                              : GPS::MTK::Utils::NMEA->envelope_wrap( $base_nmea );
    return $line;
}

sub arg_obj {
# --------------------------------------------------
    my ( $self ) = @_;
    return $self->{arg_obj} ||= do {
        GPS::MTK::Utils::Arguments->new;
    };
}

1;
