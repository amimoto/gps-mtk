# ==================================================================
#
#   GPS::MTK::Error
#   Author: Aki Mimoto
#   $Id$
#
# ==================================================================
#
# Description: 
#

package GPS::MTK::Error;
# ==================================================================

use strict;
use Exporter;
use vars qw/ 
            @ISA 
            %ERRORS 
            @EXPORT 
            $MTK_ERROR_DEFAULT 
            @ERROR_STACK
        /;
use GPS::MTK::Base;

@ISA = 'Exporter';

@EXPORT = qw();

$MTK_ERROR_DEFAULT = -1;

sub error {
# --------------------------------------------------
# The base error reporting system. All errors will be
# stored in this object until the errors flush code is called.
# This will allow the system to collect all errors that occur
# in various parts of the system in one place. Very useful
# for error reporting since it's a simple call to find
# out the last error.
# 
# Invocation of this function
#
#   $err->error( [numerical error level], ErrorMessage, ... parameters ... );
#   
#   ErrorMessage can be in the format "KEY" that will be referenced by 
#   GPS::MTK::Base->language or "KEY:Message" where if ->language does not map
#   to anything, the error will default to Message 
#
    my $self        = shift;
    my $error_level = $_[0] =~ /^\-?\d+$/ ? shift : $MTK_ERROR_DEFAULT;
    my $message     = shift;
    my $error_code;
    if ( $message    =~ /^([A-Z0-9_]+)\s*:\s*/ ) {
        $error_code = $1;
    }
    else {
        $error_code = $message;
    };
    my $text = GPS::MTK::Base->language($message,@_);
    push @ERROR_STACK, [ $text, $error_level, $text ];

    if ( $error_level < 1 ) {
        my $i = 1;
        my ( $pkg, $fn, $line );

# Proceed up the call stack until we find out where the error likely occured (ie. Not in GPS::MTK::Base)
        do { ( $pkg, $fn, $line ) = caller($i); $i++; } while ( $pkg eq 'GPS::MTK::Base' );

        $error_level < 0 ?  die "\@$fn:$pkg:$line". ' : ' .  $text . "\n"
                         : warn "\@$fn:$pkg:$line". ' : ' .  $text . "\n";
    };

#        warn "Error called wih args: @_ from " . join( " ", caller() ) . "\n";
#        require Carp;
#        Carp::cluck();

    return $text;
}

sub errors_flush {
# --------------------------------------------------
    @ERROR_STACK = ();
}


1;


