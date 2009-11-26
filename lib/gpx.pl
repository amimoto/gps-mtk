#!/usr/bin/perl

use GPS::MTK::Constants qw/:commands/;
use GPS::MTK;
use Data::Dumper;

# Figure out which serial port we're trying to use...
my $comm_port_fpath;
for ( '/dev/ttyUSB4', '/dev/ttyUSB0', '/dev/ttyACM0' ) {
    next unless -e $_;
    $comm_port_fpath = $_;
    last;
}
$comm_port_fpath or die "No comm ports found!";

# Then let's create the object that will handle our data
my $device = GPS::MTK->connect( comm_port_fpath => $comm_port_fpath );

# Download the data
my $logger_data = $device->logger_download;

# Save a copy of the raw data
open F, ">data.raw";
binmode F;
print F ${$logger_data->{binary}};
close F;

# Now, create all the GPX files
my $tracks = $logger_data->{parsed}{tracks};
for my $track (@$tracks) {
    open F, ">$track->{utc}.gpx" or die $!;
    print F $track->{gpx};
    close F;
}

