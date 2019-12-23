use strict;
use lib '../lib';

use ConfigFile;
use Benchmark qw(cmpthese);

cmpthese -5 => {
  load => sub {
    my $cf = ConfigFile->new('file.conf', multiline => {'arrays' => 1});
    $cf->load;
  },
  load2 => sub {
    my $cf = ConfigFile->new('file.conf', multiline => {'arrays' => 1});
    $cf->load2;
  },
};
