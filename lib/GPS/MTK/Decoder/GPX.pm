package GPS::MTK::Decoder::GPX;

use strict;
use bytes;
use vars qw/ @ISA $MTK_ATTRIBS /;
use GPS::MTK;
use GPS::MTK::Constants qw/:all/;
use GPS::MTK::Decoder
    ISA => 'GPS::MTK::Decoder',
    MTK_ATTRIBS =>{
    };

sub parse_cleanup {
# --------------------------------------------------
# Convert the record structure into a GPX file
#
    my ( $self, $state ) = @_;
    $state = $self->SUPER::parse_cleanup($state);
    my $tracks = $state->{tracks};

# Iterate through each set of tracks turning each of them
# into a single track
    my @gpx_tracks;
    for my $i ( 0..$#$tracks ) {
        my $j              = $i+1;
        my $track          = $tracks->[$i];
        my $track_metadata = {};
        my $headers        = shift @$track;
        my $gpx_track      = qq`<?xml version="1.0"?>
<gpx
version="1.0"
creator="GPS::MTK"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns="http://www.topografix.com/GPX/1/0"
xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">

<trk>
<name><![CDATA[]]></name>
<desc><![CDATA[]]></desc>
<number>$j</number>
<trkseg>

`;
        for my $point ( @$track ) {
            my $entry_info = {};
            @$entry_info{@$headers} = @$point;
            $gpx_track .= qq`<trkpt lat="$entry_info->{latitude}" lon="$entry_info->{longitude}">`;
            if ( my $utc = $entry_info->{utc} ) {
                my @z = gmtime $utc;
                $z[4] ++;
                $z[5] += 1900;
                $gpx_track .= sprintf qq`<time>%04i-%02i-%02iT%02i:%02i:%02iZ</time>`, reverse @z[0..5];
            }
            $gpx_track   .= qq`</trkpt>\n`;
        }

        $gpx_track .= qq`</trkseg>
</trk>
</gpx>

`;
        $track_metadata->{gpx} = $gpx_track;
        push @gpx_tracks, $track_metadata;
    }

    $state->{tracks} = \@gpx_tracks;

    return $state;
}


1;
