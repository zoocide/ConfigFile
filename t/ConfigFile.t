#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
use Test::More tests => 60;
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
  is($conf->file_name, $fname);

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
[group]
var_1 = a  complex value$space
  # comment string
var_2 = '  a complex value  '
var_5 = 'a complex
     # this is a part of the string

 new lines are saved in this string
  value'
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
a1=a b 'c d' \\'e '\\# 'f g
a2 = 'a b
 c
d' 'a 'word  tail
EOF
  my $cf = ConfigFile->new($fname, multiline=>{'gro_2'=>[qw(arr_2 arr_3 a2)]});
  eval{ $cf->load };
  ok(!$@, 'OK config file loaded');
  diag("$@") if $@;
  is($cf->get_var('group', 'var_1'), 'a complex value', 'var_1');
  is($cf->get_var('group', 'var_2'), '  a complex value  ', 'var_2');
  is($cf->get_var('group', 'var_5'), "a complex\n     # this is a part of the ".
    "string\n\n new lines are saved in this string\n  value", 'var_5');
  is($cf->get_var('gro_2', 'var_6'), 'head \'complex value\'', 'var_6');
  is($cf->get_var('gro_2', 'var_7'), '\\n is not a new line', 'var_7');
  is($cf->get_var('gro_2', 'var_8'), '', 'var_8');
  is($cf->get_var('gro_2', 'arr_1'), 'elm1', '[get_var]arr_1');
  is($cf->get_var('gro_2', 'arr_2'), 'elm1 elm2 complex element elm3 elm4 elm5', '[get_var]arr_2');
  is($cf->get_var('gro_2', 'arr_3'), 'elm1 elm2 elm3 elm4', '[get_var]arr_3');
  is($cf->get_var('gro_2', 'a1'), 'a b c d \'e \\# f g', '[get_var]a1');
  is($cf->get_var('gro_2', 'a2'), "a b\n c\nd a word tail", '[get_var]a2');
  is_deeply([$cf->get_arr('gro_2', 'arr_1')], [qw(elm1)], 'arr_1');
  is_deeply([$cf->get_arr('gro_2', 'arr_2')], [qw(elm1 elm2), 'complex element', qw(elm3 elm4 elm5)], 'arr_2');
  is_deeply([$cf->get_arr('gro_2', 'arr_3')], [qw(elm1 elm2 elm3 elm4)], 'arr_3');
  is_deeply([$cf->get_arr('gro_2', 'a1')], ['a', 'b', 'c d', '\'e', '\\# f', 'g'], 'a1');
  is_deeply([$cf->get_arr('gro_2', 'a2')], ["a b\n c\nd", 'a word', 'tail'], 'a2');
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
s0 = \${v}
s1 = ${v}
s2 = \'${v}\'
s3 = ${v}${v}
s4 = ${v1}
s5 = ${v1}${v1}
s6 = ++${v_str}${v}++
s7 = ${v1}${a}
s8 = ${a}
s9 = ${a}${v_str}
a=\"a b\"    #> [q."a., q.b".]
b="command $a" #> [q.command "a b".]
c=a$b #> [q.a"a b".].
EOF
  my $conf = ConfigFile->new($fname, multiline => {'' => [qw(v1 a s9)]});
  eval{ $conf->load };
  ok(!$@, 'config file with substitutions');
  diag("$@") if $@;

  is($conf->get_var('', 'v'), 'abc', 'variable v');
  is_deeply($conf->get_var('', 'v1'), [qw(a b c)], 'array v1');
  is($conf->get_var('', 'v_str'), "first\n last", 'variable v_str');
  is_deeply($conf->get_var('', 'abc'), [qw(a b c)], 'array a');
  is($conf->get_var('', 's0'), '${v}', 's0');
  is($conf->get_var('', 's1'), 'abc', 's1');
  is($conf->get_var('', 's2'), '\'abc\'', 's2');
  is($conf->get_var('', 's3'), 'abcabc', 's3');
  is($conf->get_var('', 's4'), 'a b c', 's4');
  is($conf->get_var('', 's5'), 'a b ca b c', 's5');
  is($conf->get_var('', 's6'), "++first\n lastabc++", 's6');
  is($conf->get_var('', 's7'), 'a b ca b c', 's7');
  is($conf->get_var('', 's8'), 'a b c', 's8');
  is_deeply($conf->get_var('', 's9'), ['a', 'b', 'c', 'first\n last'], 's9');
}
