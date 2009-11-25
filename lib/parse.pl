#!/usr/bin/perl

use strict;

use GPS::MTK::Decoder::GPX;
use Data::Dumper;

open my $fh, "<data.dump";
binmode $fh;
undef $/;
my $buf = <$fh>;
close $fh;
my $decoder = GPS::MTK::Decoder::GPX->new;
my $state = $decoder->parse( \$buf );

die Dumper $state;
