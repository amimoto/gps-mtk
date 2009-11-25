#!/usr/bin/perl

use GPS::MTK::Constants qw/:commands/;
use GPS::MTK::Command;
use Data::Dumper;

my $comm = GPS::MTK::Command->new;

warn $comm->command_string( PMTK_LOG_SETFORMAT => MTK_UTC | MTK_LATITUDE );

