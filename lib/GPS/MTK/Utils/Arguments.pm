package GPS::MTK::Utils::Arguments;

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

# If this function expects no arguments, ensure that the
# testing loop will run once with a "no argument test"
    if ( not $protos or not @$protos ) {
        $protos = [[]];
    };

    my $best_match = [ 0, undef ];
    $protos = [@$protos];
    PROTOS: for my $proto ( @$protos ) {

        $proto = [@$proto];

        my $func_match = ref $proto->[-1] eq 'CODE' ? pop @$proto : 1;

        my $i            = 0;
        my $okay         = 'MATCHED';
        my $check_param_count = 1;

# No arguments expected/wanted? Let's test for that 
        if ( not @$proto ) {
            if ( @$args ) {
                next PROTOS; # next loop, we didn't match
            }
            else {
                return $func_match || $okay;
            }
        }

# Arguments are expected ($proto is populated) we will
# iterate through
        PROTO: for my $proto_arg ( @$proto ) {
            my $v = @$args > $i ? $args->[$i] : undef;
            my $proto_arg_lc = lc $proto_arg;

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
            return $func_match || $okay; 
        };

    }

# If we have a best match, let's tell the dev of that
    if ( $best_match and $best_match->[1] ) {
        $self->{error} = "Invalid arguments. Best match: " . join( ",", @{$best_match->[1]} );
    }

    return;
};

1;
