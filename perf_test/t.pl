use strict;
use v5.10;
use lib '../lib';
use ConfigFile;
use FileHandle;

our $fname = 'f.conf';
$fname = 'big.conf';
$fname = 'big2.conf';
$fname = 'big6.conf';
$fname = 'compile.conf';
#$fname = 'big4.conf';
$fname = 'big_composit2.conf';
my $cf = ConfigFile->new($fname);
$cf->load;
{
  my ($v) = $cf->get_arr('', 'v');
  my $num = $cf->get_arr('', 'v');
  printf "%d: '%s'\n", $num, $v;
}
#print "$_:\n", map "  '$_'\n", sort $cf->get_arr('', $_) for sort $cf->var_names;
$cf->set_filename('r.conf');
$cf->save;

#print "################\n";
my %h = read2hash($fname);
#print "'$_' = '$h{$_}'\n" for sort keys %h;

use Benchmark qw(:all);

my $benchs = {
  config => sub{ConfigFile->new($fname)->load},
  read_file => sub {
    open my $f, '<', $fname;
    1 while <$f>;
    close $f;
  },
  read_filehandle => sub {
    my $f = FileHandle->new($fname, '<');
    1 while <$f>;
  },
  read_file2array => sub {
    open my $f, '<', $fname;
    my @arr;
    push @arr, $_ while <$f>;
    close $f;
  },
  read_file2hash => sub {
    my %h = read2hash($fname);
  },
  read_file2hash_words => sub {
    my %h = read2hash_words($fname);
  },
};

if (0) {
  timethese(-1, $benchs);
} else {
  my $k = 10;
  #timethese(10000, { map { $_ => $benchs->{$_} } qw(config) });
  run_test('f.conf', 2000, $k);
  run_test('big.conf', 10, $k);
  run_test('big4.conf', 10, $k);
  run_test('big_fnames.conf', 10, $k);
  run_test('big_fnames1.conf', 10, $k);
  run_test('big_fnames2.conf', 10, $k);
  run_test('big_fnames3.conf', 10, $k);
  run_test('big_composit2.conf', 10, $k);
  run_test('compile.conf', 2000, $k);
  # devel_tests()
}


sub devel_tests
{
  my $str = '\n' x 100000;
  my $ref = "\n" x 100000;
  my $h = {
    s => sub {
      my $s = $str;
      #$s =~ s/\\n/\n/g;
      $s =~ s/(\\n)|(\\t)|\\(.)/$1 ? "\n" : $2 ? "\t" : $3/ge;
      $s
    },
    m => sub {
      local $_ = $str;
      my $r = '';
      while(1) {
        my $p = pos;
        $r .= $1 if /\G([^\\]+)/gc;
        #$r .= $1 eq 'n' ? "\n" : $1 eq 't' ? "\t" : $1 if /\G\\(.)/gc;
        $r .= $_ eq 'n' ? "\n" : $_ eq 't' ? "\t" : $_ for /\G\\(.)/gc;
        last if $p == pos;
      }

      #$r .= "\n" for /\G(\\n)/gc;
      #$r .= "\n" for /\G(\\n)/gc;
      #$r .= "\n" x (() = /\G(\\n)/gc);
      #$r .= "\n" while /\G\\n/gc;
      $r
    },
  };
  say "$_: ", $ref eq $h->{$_}() ? 'ok' : 'not ok' for sort keys %$h;
  timethese(-2, $h);
}

sub run_test
{
  my ($filename, $n, $k, $func) = @_;
  use Time::HiRes qw(time);
  local $fname = $filename;
  $func //= $benchs->{config};
  say "## $fname ##";
  my @res;
  for (1..$k) {
    my $t = time;
    $func->() for 1..$n;
    $t = time - $t;
    my $r = $t > 0 ? $n/$t : 9999999999;
    say "$_: $r";
    push @res, $r;
  }
  @res = sort @res;
  ## discard 10% of the worst results. ##
  my $n_dis = int(@res / 10) || 1;
  splice @res, 0, $n_dis;
  #say for @res;
  my $res = 0;
  $res += $_ for @res;
  say "average = ", $res / @res;
}

sub read2hash
{
  my $fname = shift;
  open my $f, '<', $fname;
  my %h;
  my $ref;
  while(<$f>) {
    if (/^\s*(\w+)\s*(\@?)=\s*(.*)/) {
      $h{$1} = $3;
      $ref = \$h{$1} if $2;
    }
    else {
      $$ref .= $_
    }
  }
  close $f;
  %h
}

sub read2hash_words
{
  my $fname = shift;
  open my $f, '<', $fname;
  my %h;
  my $ref;
  while(<$f>) {
    if (/^\s*(\w+)\s*(\@?)=\s*(.*)/) {
      $h{$1} = [split /\s+/, $3];
      $ref = $h{$1} if $2;
    }
    else {
      push @$ref, split(/\s+/, $_);
    }
  }
  close $f;
  %h
}