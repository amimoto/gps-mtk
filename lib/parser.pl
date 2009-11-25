#!/usr/bin/perl

use strict;
use GPS::MTK::Constants qw/:commands/;
use GPS::MTK::Handler;
use GPS::MTK::Utils;
use Data::Dumper;
use vars qw/ @ISA @EXPORT $PI $VERSION /;


my $mydata = {};
my $handler = GPS::MTK::Handler->new;
$handler->event_hook(
    gpgga => sub {
    # --------------------------------------------------
        my ( $mydata,$verb,$args,$self,$hook_key) = @_;
        my $state    = $self->state;
        my $distance = $mydata->{prev_lon} ? GPS::MTK::Utils::distance($mydata->{prev_lat},$mydata->{prev_lon},$state->{lat},$state->{lon}) : 0;
        my $tvec     = ($state->{unixtime} - $mydata->{prev_time});
        my $speed    = ( $mydata->{prev_time} and $tvec ) ? ( $distance / $tvec ) : 0;
           $speed   *= (60*60)/1000;
        $mydata->{prev_lon}  = $state->{lon};
        $mydata->{prev_lat}  = $state->{lat};
        $mydata->{prev_time} = $state->{unixtime};
        print "".localtime($state->{unixtime})."$state->{lon},$state->{lat},$speed\n";
    }
);

open my $fh, "<data.nmea";
while ( my $l = <$fh> ) {
    $handler->handle($l,$mydata);
}
close $fh;


