# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl GPS-MTK.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 20;

#########################

require_ok('GPS::MTK');
require_ok('GPS::MTK::Utils::NMEA');
require_ok('GPS::MTK::Utils::Arguments');
require_ok('GPS::MTK::Utils::Binlog');
require_ok('GPS::MTK::IO');
require_ok('GPS::MTK::IO::Serial');
require_ok('GPS::MTK::Error');
require_ok('GPS::MTK::Handler');
require_ok('GPS::MTK::Command');
require_ok('GPS::MTK::Language');
require_ok('GPS::MTK::Device::QStarzBTQ1300');
require_ok('GPS::MTK::Device::QStarzBTQ1000');
require_ok('GPS::MTK::Device::NONMTK');
require_ok('GPS::MTK::Device::MTK');
require_ok('GPS::MTK::Base');
require_ok('GPS::MTK::Constants');
require_ok('GPS::MTK::Device');
require_ok('GPS::MTK::Utils');
require_ok('GPS::MTK::Decoder');
require_ok('GPS::MTK::Decoder::GPX');
