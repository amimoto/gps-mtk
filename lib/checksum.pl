#!/usr/bin/perl

use strict;

use GPS::MTK::Utils;
my $string = "PMTK182,2,8";
warn "RESULT: " . GPS::MTK::Utils->checksum_calc( $string ) . "\n";
warn "RESULT2: " . packet_checksum( $string ) . "\n";



sub packet_checksum {

    my $pkt   = shift;
    my $len   = length($pkt);
    my $check = 0;
    my $i;

    for ($i = 0; $i < $len; $i++) { $check ^= ord(substr($pkt, $i, 1)); }
    #printf("0x%02X\n", $check);
    return($check);
}


