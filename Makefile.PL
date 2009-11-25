use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'GPS::MTK',
    VERSION_FROM      => 'lib/GPS/MTK.pm', # finds $VERSION
    ABSTRACT          => 'Handles the proprietary extensions on MTK chipset based GPS receivers',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      ( AUTHOR         => 'Aki Mimoto <aki-cpan@bako.ca>') : ()),
);
