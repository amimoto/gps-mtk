#!/usr/bin/perl

use strict;

use GPS::MTK;
use Data::Dumper;

my $gps = GPS::MTK->new({   
                comm_port_fpath => '/dev/rfcomm3',
                events => {
                    position => sub {},
                },
            });

while ( $gps->connected ) {
    $gps->loop;
}


