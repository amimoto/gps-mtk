#!/usr/bin/perl

use GPS::MTK::Constants qw/:commands/;
use GPS::MTK;
use Data::Dumper;

my $comm_port_fpath;
for ( '/dev/ttyUSB0', '/dev/ttyACM0' ) {
    next unless -e $_;
    $comm_port_fpath = $_;
}
$comm_port_fpath or die "No comm ports found!";

my $comm = GPS::MTK->new( comm_port_fpath => $comm_port_fpath );
$comm->connect;
$comm->logger_download;
my $metadata = $comm->gps_metadata;

open F, ">data.dump";
binmode F;
print F ${$metadata->{logger}{data}};
close F;

use Data::Dumper; warn Dumper $metadata;

