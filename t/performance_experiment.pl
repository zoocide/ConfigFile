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

$test_str_part = <<'EOS';
var = one two\ \'a \# b 'a string'# comment
EOS

print "$test_str_part\n";
my @words = text2words($test_str_part);
print "<$_>\n" for @words;
print qq."@words"\n.;

# for my $size (1, 4, 16, 128, 512) {
    # print 'strings length = ', length $test_str_part, " * $size.\n";

    # $str = $test_str_part x $size;
    # cmpthese -5  => \%map;
# }


sub text2words {
  my $text = shift;
  my @ret;

  my $c;
  my $inside_string = 0;
  my $spaces_skipped;
  for my $s (split /\n/, $text) {
    while (length $s > 0) {
      if ($inside_string) {
        if ($s =~ s/^((?:[^\\']|\\.)++)'//) {
          # string finished
          $ret[-1] .= $1;
          normalize_str($ret[-1]);
          $inside_string = 0;
        }
        else {
          # string unfinished
          $ret[-1] .= $s;
          last;
        }
      }

      ## outside string ##
      ## skip spaces and comments ##
      $spaces_skipped = ($s =~ s/^\s*(?:#.*)?//); #< skip spaces and comments
      last if length $s == 0;

      ## take next word ##
      if ($s =~ s/^((?:[^\\'# \t]|\\[\\$' ])++)//) {
        # word taken
        push @ret, $1;
        normalize_str($ret[-1]);
      }
      elsif ($s =~ s/^'//) {
        # string encountered
        $inside_string = 1;
        push @ret, '';
      }
      else {
        die "unexpected string '$s' encountered";
      }
    }
  }
  @ret
}

sub normalize_str
{
  $_[0] =~ s/\\([\\\$' \t])/$1/g;
  $_[0]
}
