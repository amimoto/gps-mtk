package GPS::MTK::Constants;

# All the work related to the format of the bin dumps can be credited here:
#
# http://spreadsheets.google.com/pub?key=pyCLH-0TdNe-5N-5tBokuOA&gid=5
#
# Thanks to you guys I can actually use my GPS the way I wanted to!

use strict;
use bytes;
use Exporter;
use vars qw/
        $LOG_STORAGE_FORMAT_LOOKUP
        $DEBUG
        @ISA
        @EXPORT_OK
        %EXPORT_TAGS
        $COMMAND_DEFINITIONS @COMMANDS @COMMAND_CONSTANTS $COMMAND_PARAMETERS_LOOKUP
        $CONSTANTS_LOOKUP @CONSTANTS $CONSTANTS_DECODER_LOOKUP @CONSTANTS_DECODER
    /;
@ISA = 'Exporter';

$DEBUG = 1;

use constant ({ 
    map {($_=>$_)} 
    @COMMANDS = keys
    %{$COMMAND_DEFINITIONS = {
        PMTK_ALIVE                        => [[sub{'PTSI1000,TSI'}]],
        PMTK_TEST                         => [[sub{'PMTK000'}]],
        PMTK_CMD_HOT_START                => [[sub{'PMTK101'}]],
        PMTK_CMD_WARM_START               => [[sub{'PMTK102'}]],
        PMTK_CMD_COLD_START               => [[sub{'PMTK103'}]],
        PMTK_CMD_FULL_COLD_START          => [[sub{'PMTK104'}]],
        PMTK_LOG_SETFORMAT                => [['int',sub{'PMTK182,1,2',@_}]],
        PMTK_LOG_TIME_INTERVAL            => [['int',sub{'PMTK182,1,3',@_}]],
        PMTK_LOG_DISTANCE_INTERVAL        => [['int',sub{'PMTK182,1,4',@_}]],
        PMTK_LOG_SPEED_INTERVAL           => [['int',sub{'PMTK182,1,5',@_}]],
        PMTK_LOG_REC_METHOD               => [['int',sub{'PMTK182,1,6',@_}]],
        PMTK_LOG_QUERY                    => [['int',sub{'PMTK182,2',@_}],
                                              ['int','int',sub{'PMTK182,2',@_}]],
        PMTK_LOG_QUERY_FORMAT             => [[sub{'PMTK182,2,2'}]],
        PMTK_LOG_QUERY_TIME_INTERVAL      => [[sub{'PMTK182,2,3'}]],
        PMTK_LOG_QUERY_DISTANCE_INTERVAL  => [[sub{'PMTK182,2,4'}]],
        PMTK_LOG_QUERY_SPEED_INTERVAL     => [[sub{'PMTK182,2,5'}]],
        PMTK_LOG_QUERY_RECORDING_METHOD   => [[sub{'PMTK182,2,6'}]],
        PMTK_LOG_QUERY_STATUS             => [[sub{'PMTK182,2,7'}]],
        PMTK_LOG_QUERY_MEMORY             => [[sub{'PMTK182,2,8'}]],
        PMTK_LOG_QUERY_FLASH              => [['int',sub{'PMTK182,2,9',@_}]],
        PMTK_LOG_QUERY_POINTS             => [[sub{'PMTK182,2,10'}]],
        PMTK_LOG_ON                       => [[sub{'PMTK182,4'}]],
        PMTK_LOG_OFF                      => [[sub{'PMTK182,5'}]],
        PMTK_LOG_ERASE                    => [[sub{'PMTK182,6,1'}]],
        PMTK_LOG_REQ_DATA                 => [['int','int',sub{sprintf("PMTK182,7,%X,%X",@_)}]],

        PMTK_Q_VERSION                    => [[sub{'PMTK604'}]],
        PMTK_Q_RELEASE                    => [[sub{'PMTK605'}]],

        PMTK_ACK                          => [[sub{'PMTK001'}]],
        PMTK_DT_VERSION                   => [[sub{'PMTK704'}]],
        PMTK_DT_RELEASE                   => [[sub{'PMTK705'}]],
        PMTK_LOGGER_RESPONSE              => [[sub{'PMTK182,3'}]],
        PMTK_LOGGER_DATA                  => [[sub{'PMTK182,8'}]],
    }} 
});

###################################################
# COMMAND PARAMETER CONSTANTS
###################################################

use constant ( $COMMAND_PARAMETERS_LOOKUP = {
    MTK_UTC          => 0b0000000000000000000001,
    MTK_VALID        => 0b0000000000000000000010,
    MTK_LATITUDE     => 0b0000000000000000000100,
    MTK_LONGITUDE    => 0b0000000000000000001000,
    MTK_HEIGHT       => 0b0000000000000000010000,
    MTK_SPEED        => 0b0000000000000000100000,
    MTK_HEADING      => 0b0000000000000001000000,
    MTK_DSTA         => 0b0000000000000010000000,
    MTK_DAGE         => 0b0000000000000100000000,
    MTK_PDOP         => 0b0000000000001000000000,
    MTK_HDOP         => 0b0000000000010000000000,
    MTK_VDOP         => 0b0000000000100000000000,
    MTK_NSAT         => 0b0000000001000000000000,
    MTK_SID          => 0b0000000010000000000000,
    MTK_ELEVATION    => 0b0000000100000000000000,
    MTK_AZIMUTH      => 0b0000001000000000000000,
    MTK_SNR          => 0b0000010000000000000000,
    MTK_RCR          => 0b0000100000000000000000,
    MTK_MILISECOND   => 0b0001000000000000000000,
    MTK_DISTANCE     => 0b0010000000000000000000,
    MTK_LOGVALIDONLY => 0b0100000000000000000000,

    MTK_DATA_OVERWRITE => 1,
    MTK_DATA_STOP      => 0,
} );

###################################################
# BINARY DUMP DECODER CONSTANTS
###################################################

use constant ( $CONSTANTS_DECODER_LOOKUP = {

    LOG_BLOCK_SIZE                    => 0x10000,
    LOG_HEADER_INFO_SIZE              => 20,
    LOG_SECTOR_INFO_SIZE              => 32,
    LOG_HEADER_PADDING_SIZE           => 460,

    LOG_ENTRY_SEPARATOR_PREFIX        => chr(0xAA) x 7,
    LOG_ENTRY_SEPARATOR_PREFIX_LENGTH => length(chr(0xAA) x 7),
    LOG_ENTRY_SEPARATOR_SUFFIX        => chr(0xBB) x 4,
    LOG_ENTRY_SEPARATOR_SUFFIX_LENGTH => length(chr(0xBB) x 4),

    LOG_ENTRY_SEPARATOR_BITMASK       => 0x02,
    LOG_ENTRY_SEPARATOR_PERIOD        => 0x03,
    LOG_ENTRY_SEPARATOR_DISTANCE      => 0x04,
    LOG_ENTRY_SEPARATOR_SPEED         => 0x05,
    LOG_ENTRY_SEPARATOR_OVERWRITE     => 0x06,
    LOG_ENTRY_SEPARATOR_POWERCYCLE    => 0x07,

    LOG_STORAGE_FORMAT                => do {
                                            my $list = [
                                                [ utc          => 'L' ],
                                                [ valid        => 'S' ],
                                                [ latitude     => 'd' ],
                                                [ longitude    => 'd' ],
                                                [ height       => 'f' ],
                                                [ speed        => 'f' ],
                                                [ heading      => 'f' ],
                                                [ dsta         => 'f' ],
                                                [ dage         => 'L' ],
                                                [ pdop         => 'S' ],
                                                [ hdop         => 'S' ],
                                                [ vdop         => 'S' ],
                                                [ nsat         => 'CC' ],
                                                [ sid          => 'C' ],
                                                [ elevation    => 'S' ],
                                                [ azimuth      => 'S' ],
                                                [ snr          => 'S' ],
                                                [ rcr          => 'S' ],
                                                [ milisecond   => 'S' ],
                                                [ distance     => 'd' ],
                                                [ logvalidonly => 's' ],
                                            ];
                                            my $i = 0;
                                            my $fmt = {
                                                map {;
                                                    $_->[0] => {
                                                        format   => $_->[1],
                                                        bit_mask => 2**$i,
                                                        order    => $i++,
                                                        numbytes => length(pack $_->[1]),
                                                    },
                                                } @$list
                                            };

                                            $fmt;
                                            },
} );

use constant ( $CONSTANTS_LOOKUP = {

        NMEA_CHECKSUM_IGNORE              => 0,
        NMEA_CHECKSUM_PRESENCE            => 1,
        NMEA_CHECKSUM_IF_PRESENT          => 2,
        NMEA_CHECKSUM_STRICT              => 3,

        EARTH_RADIUS                      => 6372797.6,
        RADIANS_IN_DEGREE                 => 3.14159290045661 * 2 / 360,
        DEGREE_IN_RADIANS                 => 360 / 3.14159290045661 * 2,
        PI                                => 3.14159290045661,

    } );

use constant {
        LOG_STORAGE_FORMAT_KEYS => [ sort {LOG_STORAGE_FORMAT()->{$a}{order} <=> LOG_STORAGE_FORMAT()->{$b}{order}} keys %{LOG_STORAGE_FORMAT()} ],
    };

@CONSTANTS = keys %$CONSTANTS_LOOKUP;
@COMMAND_CONSTANTS = keys %$COMMAND_PARAMETERS_LOOKUP;
@CONSTANTS_DECODER = ( keys(%$CONSTANTS_DECODER_LOOKUP),'LOG_STORAGE_FORMAT_KEYS' );
@EXPORT_OK = ( @CONSTANTS, @COMMANDS, '$COMMAND_DEFINITIONS', @COMMAND_CONSTANTS, @CONSTANTS_DECODER );
%EXPORT_TAGS = ( 
    all       => \@EXPORT_OK,
    constants => \@CONSTANTS,
    decoder   => \@CONSTANTS_DECODER,
    commands  => [ @COMMANDS, @COMMAND_CONSTANTS ],
);

###################################################
# Initialization routines for various values/constants
###################################################

my $i = 0;
for my $k ( @{&LOG_STORAGE_FORMAT_KEYS} ) {
    $LOG_STORAGE_FORMAT_LOOKUP->{$k} = 2**$i;
    $i++;
};


1;


