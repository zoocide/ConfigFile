#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
use Test::More tests => 156;
use File::Temp qw(tempfile);

use Exceptions;

BEGIN{ use_ok('ConfigFile') }

my (undef, $fname) = tempfile();

eval {
  my $conf;

  ## create new config file ##
  eval{ $conf = ConfigFile->new($fname) };
  ok(!$@, "create new ConfigFile");
  isa_ok($conf, 'ConfigFile');

  ## fill config file ##
  # check set_var, set_group
  eval {
    $conf->set_var('name', 'MyConf');
    $conf->set_var('plugin', 'Plugin');
    $conf->set_group('info');
    $conf->set_var('date', '21.12.2012');
    $conf->set_var('time', '13:42:59');
    $conf->set_group('');
    $conf->set_var('list', qw(one two three));
  };
  ok(!$@, 'set variables');

  ## check variables in config file ##
  # check get_var
  is($conf->get_var(''    , 'name'  ), 'MyConf'    );
  is($conf->get_var(''    , 'plugin'), 'Plugin'    );
  is($conf->get_var('info', 'date'  ), '21.12.2012');
  is($conf->get_var('info', 'time'  ), '13:42:59'  );
  is($conf->get_var(''    , 'list'  ), 'one two three');
  is_deeply([$conf->get_arr('', 'list')], [qw(one two three)]);
  ok(!defined $conf->get_var('group_not_existed', 'var_not_existed'));
  ok(!defined $conf->get_var('', 'var_not_existed'));
  is($conf->get_var('', 'var_not_existed', 'default'), 'default', 'get_var with default');

  # check is_set
  ok($conf->is_set(''    , 'name'  ));
  ok($conf->is_set(''    , 'plugin'));
  ok($conf->is_set('info', 'date'  ));
  ok($conf->is_set('info', 'time'  ));
  ok($conf->is_set(''    , 'list'  ));
  ok(!$conf->is_set('group_not_existed', 'var_not_existed'));
  ok(!$conf->is_set('', 'var_not_existed'));

  # check set_var_if_not_exists
  eval {
    $conf->set_group('info');
    $conf->set_var_if_not_exists('version', '0.1.0');
    $conf->set_var_if_not_exists('date', '01.01.2012');
  };
  ok(!$@, 'set variables if not exists');
  is($conf->get_var('info', 'date'   ), '21.12.2012');
  is($conf->get_var('info', 'version'), '0.1.0');

  # check file_name
  is($conf->filename, $fname);

  ## save config file ##
  eval{ $conf->save };
  ok(!$@, 'config file saved');


  ## create new config file ##
  eval{ $conf = ConfigFile->new($fname) };
  ok(!$@, "create new ConfigFile");
  isa_ok($conf, 'ConfigFile');

  ## load config file from file ##
  eval{ $conf->load };
  ok(!$@, 'config file loaded');
  diag("$@") if $@;

  ## check content of the config file ##
  is($conf->get_var(''    , 'name'   ), 'MyConf'    );
  is($conf->get_var(''    , 'plugin' ), 'Plugin'    );
  is($conf->get_var('info', 'date'   ), '21.12.2012');
  is($conf->get_var('info', 'time'   ), '13:42:59'  );
  is($conf->get_var('info', 'version'), '0.1.0'     );
  is($conf->get_var(''    , 'list'  ), 'one two three');
  is_deeply([$conf->get_arr('', 'list')], [qw(one two three)]);
  ok(!defined $conf->get_var('group_not_existed', 'var_not_existed'));
  ok(!defined $conf->get_var('', 'var_not_existed'));
  # check is_set
  ok($conf->is_set(''    , 'name'  ));
  ok($conf->is_set(''    , 'plugin'));
  ok($conf->is_set('info', 'date'  ));
  ok($conf->is_set('info', 'time'  ));
  ok(!$conf->is_set('group_not_existed', 'var_not_existed'));
  ok(!$conf->is_set('', 'var_not_existed'));

  check_config_file_rules($fname);
  check_variables_substitution($fname);
  check_shield_str($fname);
  check_array($fname);
  check_scheme($fname);
};

## finally ##
unlink $fname if -e $fname;
throw if $@;

sub fill_file
{
  my $fname = shift;
  open my $f, '>', $fname or diag("cannot open file $fname:$!\n") && return 0;
  print $f @_;
  close $f;
  1
}

sub check_config_file_rules
{
  my $fname = shift;
  ## check config file rules ##
  # error: [complex group]
  # ok   : [group]
  # error: var name with spaces = value
  # ok   : var_1 = a complex value
  # ok   :   # comment string
  # ok   : var_2 = '  a complex value  '
  # error: var_3 = 'a complex value
  # ok   : var_4 = 'a complex value' tail
  # ok   : var_5 = 'a complex
  # ok   :      # this is a part of the string
  # ok   :
  # ok   :  new lines are saved in this string
  # ok   :   value'
  # ok   : var_6 = head \'complex value\'
  # ok   : var_7 = \\n is not a new line
  # ok   : # set empty value
  # ok   : var_8 =
  # error:   value
  # ok   : arr_1 = elm1 elm2
  # ok   : arr_2 = elm1 elm2 'complex element'
  # ok   : elm3
  # ok   :   elm4 elm5
  # ok   : arr_3 =
  # ok   : elm1 elm2 elm3 elm4
  # ok   : a1=a b 'c d' \'e '\\# 'f g

  ## OK ##
  my $space = ' '; #< prevents accidentally removing space at the end of line
  fill_file($fname, <<EOF);
v=1
[group]
var_1 = a  complex value$space
  # comment string
var_2 = '  a complex value  '
var_5 = 'a complex
     # this is a part of the string

 new lines are saved in this string
  value'
qq_str = "\\n\\\\\\t"
[gro_2]
var_6 = head \\'complex  value\\'
var_7 = \\\\n is not a new line
# set empty value
var_8 =
arr_1 = elm1
arr_2 = elm1 elm2 'complex element'
elm3
  elm4 elm5
arr_3 =
elm1 elm2 elm3 elm4
arr_4 @= 1
2
 3
a1=a b 'c d' \\'e '\\# 'f g
a2 = 'a b
 c
d' 'a 'word  tail
EOF
  my $cf = ConfigFile->new($fname, multiline=>{'gro_2'=>[qw(arr_2 arr_3 a2)]});
  $cf->set_group('args');
  $cf->set_var('preset_var', 'value');
  eval{ $cf->load };
  ok(!$@, 'OK config file loaded');
  diag("$@") if $@;
  is($cf->get_var('', 'v'), '1');
  is($cf->get_var('args', 'preset_var'), 'value', 'preset_var');
  is($cf->get_var('group', 'var_1'), 'a complex value', 'var_1');
  is($cf->get_var('group', 'var_2'), '  a complex value  ', 'var_2');
  is($cf->get_var('group', 'var_5'), "a complex\n     # this is a part of the ".
    "string\n\n new lines are saved in this string\n  value", 'var_5');
  is($cf->get_var('group', 'qq_str'), "\n\\\t", 'qq_str');
  is($cf->get_var('gro_2', 'var_6'), 'head \'complex value\'', 'var_6');
  is($cf->get_var('gro_2', 'var_7'), '\\n is not a new line', 'var_7');
  is($cf->get_var('gro_2', 'var_8'), '', 'var_8');
  is($cf->get_var('gro_2', 'arr_1'), 'elm1', '[get_var]arr_1');
  is($cf->get_var('gro_2', 'arr_2'), 'elm1 elm2 complex element elm3 elm4 elm5', '[get_var]arr_2');
  is($cf->get_var('gro_2', 'arr_3'), 'elm1 elm2 elm3 elm4', '[get_var]arr_3');
  is($cf->get_var('gro_2', 'arr_4'), '1 2 3', '[get_var]arr_4');
  is($cf->get_var('gro_2', 'a1'), 'a b c d \'e \# f g', '[get_var]a1');
  is($cf->get_var('gro_2', 'a2'), "a b\n c\nd a word tail", '[get_var]a2');
  is_deeply([$cf->get_arr('gro_2', 'arr_1')], [qw(elm1)], 'arr_1');
  is_deeply([$cf->get_arr('gro_2', 'arr_2')], [qw(elm1 elm2), 'complex element', qw(elm3 elm4 elm5)], 'arr_2');
  is_deeply([$cf->get_arr('gro_2', 'arr_3')], [qw(elm1 elm2 elm3 elm4)], 'arr_3');
  is_deeply([$cf->get_arr('gro_2', 'a1')], ['a', 'b', 'c d', '\'e', '\# f', 'g'], 'a1');
  is_deeply([$cf->get_arr('gro_2', 'a2')], ["a b\n c\nd", 'a word', 'tail'], 'a2');

  fill_file($fname, <<'EOF');
v1 = line \
continuation\\
v2 = variable\
   with \
multi\\\
ple \\\\\
\
\\\
continuation
#comment \
with continuation
s1='\
'
s2='\\\
 \
'
s3="\\\
\\"\

v3=\\\
EOF
  eval{ $cf->load; }; is($@ ? "$@" : '', '', 'load continuation test file');
  is($cf->get_var('', 'v1'), 'line continuation\\');
  is($cf->get_var('', 'v2'), 'variable with multi\ple \\\\\\continuation');
  is($cf->get_var('', 'v3'), '\\');
  is($cf->get_var('', 's1'), '');
  is($cf->get_var('', 's2'), '\\ ');
  is($cf->get_var('', 's3'), '\\\\');
  isnt(load_file($fname, 'a="\\'), '');
}

sub check_variables_substitution
{
  my $fname = shift;
## check variables substitution ##
  fill_file($fname, <<'EOF');
#config file
v=abc
v1=a b c
v_str='first
 last'
abc=a
  b
  c
q_text = ' $abc
 $v
 end $v' #<[" \$abc\n \$v\n end \$v"]
qq_text = " $abc
 $v
 end $v" #<[" a b c\n abc\n end abc"]
s0 = \${v}    #< no substitution
s00= '$v${v}' #< no substitution
s1 = $v       #< simple one word substitution
s2 = \'${v}\' #< braced substitution with concatenation
s3 = ${v}${v} #< braced twice substitution with concatenation
s4 = ${v1}    #< braced list substitution
s5 = ${v1}${v1} #< braced twice scalar substitution with concatenation
s6 = ++$v_str${v}++ #< mixed scalar substitution with concatenation
s7 = $v1$abc  #< simple twice scalar substitution with concatenation
s8 = ${abc} $abc   #< braced multiline substitution
s9 = $abc${v_str} #< mixed substitution with concatenation
a=\"a b\"     #> [q."a., q.b".]
b="command $a"#> [q.command "a b".]
c=a$a         #> [q.a"a b".].
[gr]
a=aa
b=$a${::a}${gr::a} #> [q.aa"a b"aa.]
[gr2]
v=\#
v1=$ $$
v2=$
v3=v
v4=$v2''$v3''$v2''$v3
a=$v${v}${::v}${gr::a}${gr2::v} #> [q.##abcaa#.]
EOF
  my $conf = ConfigFile->new($fname, multiline => {'' => [qw(abc s9)]});
  eval{ $conf->load };
  ok(!$@, 'config file with substitutions');
  diag("$@") if $@;

  is($conf->get_var('', 'v'), 'abc', 'variable v');
  is($conf->get_var('', 'v1'), 'a b c', 'array v1');
  is($conf->get_var('', 'v_str'), "first\n last", 'variable v_str');
  is($conf->get_var('', 'abc'), 'a b c', 'array a');
  is($conf->get_var('', 'q_text'), " \$abc\n \$v\n end \$v", 'q_text');
  is($conf->get_var('', 'qq_text'), " a b c\n abc\n end abc", 'qq_text');
  is($conf->get_var('', 's0'), '${v}', 's0');
  is($conf->get_var('', 's00'), '$v${v}', 's00');
  is($conf->get_var('', 's1'), 'abc', 's1');
  is($conf->get_var('', 's2'), '\'abc\'', 's2');
  is($conf->get_var('', 's3'), 'abcabc', 's3');
  is($conf->get_var('', 's4'), 'a b c', 's4');
  is($conf->get_var('', 's5'), 'a b ca b c', 's5');
  is($conf->get_var('', 's6'), "++first\n lastabc++", 's6');
  is($conf->get_var('', 's7'), 'a b ca b c', 's7');
  is($conf->get_var('', 's8'), 'a b c a b c', 's8');
  is($conf->get_var('', 's9'), "a b cfirst\n last", 's9');
  is($conf->get_var('', 'a'), '"a b"', 'a');
  is($conf->get_var('', 'b'), 'command "a b"', 'b');
  is($conf->get_var('', 'c'), 'a"a b"', 'c');
  is($conf->get_var('gr', 'a'), 'aa', 'gr::a');
  is($conf->get_var('gr', 'b'), 'aa"a b"aa', 'gr::b');
  is($conf->get_var('gr2', 'v'), '#', 'gr2::v');
  is($conf->get_var('gr2', 'v1'), '$ $$', 'gr2::v1');
  is($conf->get_var('gr2', 'v2'), '$', 'gr2::v2');
  is($conf->get_var('gr2', 'v4'), '$v$v', 'gr2::v4');
  is($conf->get_var('gr2', 'a'), '##abcaa#', 'gr2::a');
  is($conf->get_var('', 's9'), "a b cfirst\n last", 's9');
  is_deeply([$conf->get_arr('', 'v' )], ['abc']);
  is_deeply([$conf->get_arr('', 'v1')], [qw(a b c)]);
  is_deeply([$conf->get_arr('', 'v_str')], ["first\n last"]);
  is_deeply([$conf->get_arr('', 'abc')], [qw(a b c)]);
  is_deeply([$conf->get_arr('', 's0')], ['${v}']);
  is_deeply([$conf->get_arr('', 's00')], ['$v${v}']);
  is_deeply([$conf->get_arr('', 's1')], ['abc']);
  is_deeply([$conf->get_arr('', 's2')], ['\'abc\'']);
  is_deeply([$conf->get_arr('', 's3')], ['abcabc']);
  is_deeply([$conf->get_arr('', 's4')], [qw(a b c)]);
  is_deeply([$conf->get_arr('', 's5')], ['a b ca b c']);
  is_deeply([$conf->get_arr('', 's6')], ["++first\n lastabc++"]);
  is_deeply([$conf->get_arr('', 's7')], ['a b ca b c']);
  is_deeply([$conf->get_arr('', 's8')], [qw(a b c a b c)]);
  is_deeply([$conf->get_arr('', 's9')], ["a b cfirst\n last"]);
  is_deeply([$conf->get_arr('', 'a')], [qw("a b")]);
  is_deeply([$conf->get_arr('', 'b')], ['command "a b"']);
  is_deeply([$conf->get_arr('', 'c')], ['a"a b"']);
  is_deeply([$conf->get_arr('gr', 'a')], ['aa']);
  is_deeply([$conf->get_arr('gr', 'b')], ['aa"a b"aa']);
  is_deeply([$conf->get_arr('gr2', 'v')], ['#']);
  is_deeply([$conf->get_arr('gr2', 'v1')], [qw($ $$)]);
  is_deeply([$conf->get_arr('gr2', 'a')], ['##abcaa#']);

  fill_file($fname, "a=a b c\nb=d e f\nc=\$a \$b");
  eval{ $conf->load; }; is($@ ? "$@" : '', '', 'load substitution test file');
  is_deeply([$conf->get_arr('', 'c')], [qw(a b c d e f)]);
}

sub check_shield_str
{
  my $fname = shift;
  my $conf = ConfigFile->new($fname);

  my %vars = (
    v0 => '',
    v1 => 'word',
    v2 => 'two words',
    v3 => '$',
    v4 => '#it is not a comment',
    v5 => '\\',
    v6 => q.'quotes'.,
    v7 => '"double quotes"',
    v8 => '\'',
    v9 => '"',
    v10 => '$$',
    v11 => "\n",
    v12 => "a\n",
    v13 => " \n",
    v14 => "\n ",
    v15 => "\n \n",
    v16 => "\n\n",
  );
  $conf->set_var($_ => $vars{$_}) for keys %vars;
  $conf->save;

  $conf = ConfigFile->new($fname);
  eval{ $conf->load };
  ok(!$@, 'check_shield_str: config file loaded');
  diag("$@") if $@;
  is($conf->get_var('', $_), $vars{$_}, $_) for sort keys %vars;
}

sub check_array
{
  my $fname = shift;
  my %vars = (
    v0 => [qw()],
    v1 => [qw(word)],
    v2 => [qw(two words)],
    v3 => ['#it', qw(is not a comment), '\#'],
    v4 => [qw(list with string), "a string\n###"],
  );

  my $conf = ConfigFile->new($fname);
  $conf->set_var($_ => @{$vars{$_}}) for keys %vars;
  $conf->save;

  $conf = ConfigFile->new($fname);
  eval{ $conf->load };
  ok(!$@, 'check_array: config file loaded');
  diag("$@") if $@;
  is_deeply([$conf->get_arr('', $_)], $vars{$_}, $_) for sort keys %vars;
}

sub load_file
{
  my ($fname, $text, @scheme) = @_;
  fill_file($fname, $text);
  my $conf = ConfigFile->new($fname, @scheme);
  eval{ $conf->load };
  $@ ? "$@" : ''
}

sub check_scheme
{
  my $fname = shift;
  is(load_file($fname, <<'EOF', multiline => {'' => [qw(a)]}), '');
a = 1
2
EOF
  isnt(load_file($fname, <<'EOF'), '');
a = 1
2
EOF
  is(load_file($fname, 'a=1', required => {'' => [qw(a)]}), '');
  isnt(load_file($fname, 'a=1', required => {'' => [qw(b)]}), '');
  is(load_file($fname, 'a=1', strict => 1, struct => {'' => [qw(a)]}), '');
  isnt(load_file($fname, 'b=1', strict => 1, struct => {'' => [qw(a)]}), '');
}
