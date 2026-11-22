#!/usr/bin/perl -w
use v5.10;
use strict;

my %vars = (
  '' => {
  b => 'foo',
  c => '-',
  afoo => 'baz',
  },
  a => {
    foo => '$$$',
    blank => ':subgroup:',
  },
);
$_ = 'a${b}${a:${a::blank}:${b}}${${c}a}';
$_ = interpolate($_);
say;
my $ra = qr~(?'a'\w)~;
my $re = qr~$ra|:$ra~;
'a' =~ /$re/ && say $+{a}//':(';
'b' =~ /$re/ && say $+{a} //':(';
':abc' =~ m~(?:$re(?{ say $+{a} // '#' }))+~ && say '   !', $+{a} //':(';

## fix glob error ##
my @fls = (
  q#a b.txt#,
  q#'a b.txt#,
  q#'a b' c.txt#,
  q#=a b c.txt#,
  q#a $b.txt#,
);
@fls = map glob_escape_str($_), @fls;
say for @fls;
say "#####";
for (map glob, @fls) {
  say "$_", -e ? " exists" : ();
}

sub glob_escape_str
{
  local $_ = shift;
  s/(['"])|(\s+)/$1 ? '\\'.$1 : "'$2'"/eg;
  $_
}

sub glob_single_word
{
  local $_ = shift;
  my $p;
  while(1) {
    /\G(?:
      (?:\\.)++ |
      (?> '(?: \\' | [^\\']+ | \\ )*' ) |
      (?> "(?: \\. | [^\\"]+ )*" ) |
      [^ \t\n\\'"]++
      # | ['"] Shell does not allow unclosed quotes.
    )+/gcx;
    #say "# ", pos;
    if (s/\G(\s+)/say pos; $p = pos() + length($1) + 2; "'$1'"/e) {
      pos = $p;
      redo;
    }
    last;
  }
  $_
}


sub interpolate
{
  my $var_spec = qr~(?:(?'vg'(?>\w+))::)?(?'vn'(?>\w+))~;
  my $substitute_flat = sub {
    my $s = shift;
    $s =~ /^$var_spec$/ ? $vars{$+{vg}//''}{$+{vn}} : undef;
  };
  my $interpolate_func;
  $interpolate_func = sub {
    my $s = shift;
    $s =~ s~
      \$\{
        (?:
          $var_spec|
          (?'nest'(?:(?R)|(?>[\w:]+))+)
        )
      \}
      ~
        my $t;
        defined $+{vn} ? $vars{$+{vg}//''}{$+{vn}}
        : $substitute_flat->($t = $interpolate_func->($+{nest})) // "\${$t}"
      ~exg;
    $s
  };
  $interpolate_func->($_[0])
}
