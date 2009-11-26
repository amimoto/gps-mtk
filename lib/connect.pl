#!/usr/bin/perl

use GPS::MTK::Constants qw/:commands/;
use GPS::MTK;
use Data::Dumper;

# Figure out which serial port we're trying to use...
my $comm_port_fpath;
for ( '/dev/ttyUSB0', '/dev/ttyACM0' ) {
    next unless -e $_;
    $comm_port_fpath = $_;
}
$comm_port_fpath or die "No comm ports found!";

# Then let's create the object that will handle our data
my $device = GPS::MTK->connect( comm_port_fpath => $comm_port_fpath );

# Download the data
my $logger_data = $device->logger_download;

# Save the retrieved data
my $metadata = $device->gps_metadata;
open F, ">data.dump";
binmode F;
print F ${$metadata->{logger}{data}};
close F;

open F, ">data.gpx";
binmode F;
print F Dumper( $logger_data );
close F;

