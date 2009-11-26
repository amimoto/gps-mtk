#!/usr/bin/perl

use strict;

use GPS::MTK::Decoder::GPX;
use Data::Dumper;

# Just load in all the raw data
open my $fh, "<data.raw";
binmode $fh;
undef $/;
my $buf = <$fh>;
close $fh;

# Now parse 'er
my $decoder = GPS::MTK::Decoder::GPX->new;
my $state = $decoder->parse( \$buf );

# And finally, we can just dump the data into a bunch of files
my $tracks = $state->{tracks};
for my $track (@$tracks) {
    open F, ">$track->{utc}.gpx" or die $!;
    print F $track->{gpx};
    close F;
}

