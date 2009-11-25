{ # ##################################################

package GPS::MTK::Commands;

use strict;

use GPS::MTK::Base
    MTK_ATTRIBS => {
    };

sub proto_match {
# --------------------------------------------------
# does a basic scan through of all the prototypes
#
    my ( $self, $args, $protos ) = @_;

    ref $self or $self = $self->new;

    my $best_match = [ 0, undef ];
    PROTOS: for my $proto ( @$protos ) {
        $proto = [@$proto];

use Data::Dumper; warn Dumper $proto;
        my $func_match = ref $proto->[-1] eq 'CODE' ? pop @$proto : 1;

        my $i            = 0;
        my $okay         = 1;
        my $check_param_count = 1;

        PROTO: for my $proto_arg ( @$proto ) {
            my $v = @$args > $i ? $args->[$i] : undef;
            my $proto_arg_lc = lc $proto_arg;

            warn( ("---" x $i) . " " . $proto_arg . "\n");

            if ( $proto_arg =~ /ref:(.*)/ ) {
                UNIVERSAL::isa( $v, $1 );
            }

            elsif ( $proto_arg_lc eq 'any' ) {
            }

            elsif ( $proto_arg_lc eq '...' ) { # everything'll match :)
                $check_param_count = 0;
                last PROTO;
            }

            elsif ( ref $v ) {
                $okay = 0; last PROTO; # it won't match anything
            }

            elsif ( not defined $v ) {
                $okay = 0; last PROTO; # it won't match anything
            }

            elsif ( $proto_arg_lc eq 'int' ) {
                if ( $v !~ /^\d+$/ ) {
                    $okay = 0; last PROTO;
                };
            }

            elsif ( $proto_arg_lc eq 'float' ) {
                if ( $v !~ /^\d+(\.\d+)?$/ ) {
                    $okay = 0; last PROTO;
                }
            }

            elsif ( $proto_arg_lc eq 'string' ) {
            }

            elsif ( $proto_arg_lc eq 'date' ) {
                if ( $v !~ /^\d+-\d+-\d+?$/ ) {
                    $okay = 0; last PROTO;
                }
            }

            $i++;

            if ( $okay and $best_match->[0] < $i ) {
                $best_match = [$i,$proto];
            }

        }

        if ( $okay ) { 
            if ( $check_param_count and @$args != @$proto ) {
                next;
            }
            return $func_match 
        };

    }

# If we have a best match, let's tell the dev of that
    if ( $best_match and $best_match->[1] ) {
        $self->{error} = "Invalid arguments. Best match: " . join( ",", @{$best_match->[1]} );
    }

    return;
};

}; # ##################################################

my $commands = {
    PMTK_TEST => [
                    [ 
                        [ 'Int' ], 
                        [ 'String' ], 
                        [ 'String', 'Any' ],
                        [ 'Date', '...' ] 
                    ] => sub {},
                ],
};

my $command = GPS::MTK::Commands->new;
my $res_fun = $command->proto_match(
    [ 1, 2 ],
    [ 
        [ 'Int' => sub { print "foo!" } ], 
        [ 'String' ], 
        [ 'String', 'Any' => sub { print "matched any!" } ],
        [ 'Date', '...' => sub { print "found date!" }  ] 
    ]
) or die "Invalid Arguments\n";
warn "$res_fun\n\n";
$res_fun->();

exit;
my $command = GPS::MTK::Commands->new;
$command->proto_match(
    [ 1, 2, 3 ],
    [ 
        [ 'Int' => sub { print "foo!" } ], 
        [ 'String' ], 
        [ 'String', 'Any' ],
        [ 'Date', '...' ] 
    ]
) or die "Invalid Arguments\n";



