use 5.00008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'ConfigFile',
    VERSION_FROM      => 'lib/ConfigFile.pm', # finds $VERSION
    PREREQ_PM         => {
      Test::More => 0,
      File::Temp => 0,
      Exceptions => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/ConfigFile.pm', # retrieve abstract from module
       AUTHOR         => 'Alexander Smirnov <zoocide@gmail.com>') : ()),
);
