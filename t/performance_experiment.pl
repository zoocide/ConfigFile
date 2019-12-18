#!/usr/bin/perl -w
use strict;
use Benchmark qw /timethese cmpthese/;

our ($char, $str);

my %map = (
  regex => sub {
    my $s = $str;
    $s =~ s/\\(\\|#)|#.*/defined $1 ? $1 : ''/eg;
    $s
  },
  substr => sub {
    my $s = $str;
    my $c;
    my $special = 0;
    my $out = '';
    for my $i (0 .. length($s) - 1) {
      $c = substr $s, $i, 1;
      if ($special) {
        $special = 0;
        $out .= '\\' if $c ne '\\' && $c ne '#';
      }
      elsif ($c eq '\\') {
        $special = 1;
        next;
      }
      elsif ($c eq '#') {
        last;
      }
      $out .= $c;
    }
    $out;
  },
  substr2 => sub {
    my $s = $str;
    my $c;
    my $special = 0;
    my $out = '';
    for my $i (0 .. length($s) - 1) {
      $c = substr $s, $i, 1;
      if ($special) {
        $special = 0;
        $c = '\\'.$c if $c ne '\\' && $c ne '#';
      }
      elsif ($c eq '\\') {
        $special = 1;
        next;
      }
      elsif ($c eq '#') {
        last;
      }
      $out .= $c;
    }
    $out;
  },
);

my @tests = (
  ['asjdfkiasjdnfcaiksjdn#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn'],
  ['asjdfkiasjdnfcaiksjdn\\#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn#sdafodsjfoaj'],
  ['asjdfkiasjdnfcaiksjdn\\\\\\#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn\\#sdafodsjfoaj'],
  ['asjdfkiasjdnfcaiksjdn\\\\#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn\\'],
  ['\a\s\j\d\f\\\\kiasjdnfcaiksjdn#sdafodsjfoaj', '\a\s\j\d\f\\kiasjdnfcaiksjdn'],
);
my $expect;
for (@tests) {
  ($str, $expect) = @$_;
  print "check '$str' expect '$expect'\n";
  while (my ($k, $v) = each %map) {
    my $r = &$v;
    $r eq $expect or die "wrong $k:\ngot\n  '$r'\nexpect\n  '$expect'\n";
  }
}

my $test_str_part = <<'EOS';
my @tests = (
  ['asjdfkiasjdnfcaiksjdn\#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn'],
  ['asjdfkiasjdnfcaiksjdn\\\#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn\#sdafodsjfoaj'],
  ['asjdfkiasjdnfcaiksjdn\\\\\\\#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn\\\#sdafodsjfoaj'],
  ['asjdfkiasjdnfcaiksjdn\\\\\#sdafodsjfoaj', 'asjdfkiasjdnfcaiksjdn\\'],
  ['\a\s\j\d\f\\\\kiasjdnfcaiksjdn\#sdafodsjfoaj', '\a\s\j\d\f\\kiasjdnfcaiksjdn'],
);
EOS

for my $size (1, 4, 16, 128, 512) {
    print 'strings length = ', length $test_str_part, " * $size.\n";

    $str = $test_str_part x $size;
    cmpthese -5  => \%map;
}
