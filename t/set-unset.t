use strict;
use Test::More tests => 25;
use ConfigFile;

my $cf = ConfigFile->new;

$cf->set('gr', 'v', 1, 'a');
$cf->set('gr', 'v1', 1);
$cf->set('gr', 'v2', 1);
$cf->set(undef, 'v', 'b');
$cf->set_var('v1', 'c');
$cf->set_var('v2', 'd');
ok($cf->is_set('gr', 'v'));
ok($cf->is_set('gr', 'v1'));
ok($cf->is_set('gr', 'v2'));
ok($cf->is_set('', 'v'));
ok($cf->is_set('', 'v1'));
ok($cf->is_set('', 'v2'));
is_deeply([$cf->get_arr('gr', 'v')], [1, 'a']);
is($cf->get_var('', 'v'), 'b');
is($cf->get_var('', 'v1'), 'c');
is($cf->get_var('', 'v2'), 'd');

$cf->unset('gr', 'v');
ok(!$cf->is_set('gr', 'v'));
ok($cf->is_set('gr', 'v1'));
ok($cf->is_set('gr', 'v2'));
ok($cf->is_set('', 'v'));
ok($cf->is_set('', 'v1'));

$cf->unset('gr');
ok(!$cf->is_set('gr', 'v1'));
ok(!$cf->is_set('gr', 'v2'));
ok($cf->is_set('', 'v'));
ok($cf->is_set('', 'v1'));

$cf->unset(undef, 'v');
ok(!$cf->is_set('', 'v'));
ok($cf->is_set('', 'v1'));
ok($cf->is_set('', 'v2'));

$cf->set('foo', 'v1');
$cf->unset;
ok(!$cf->is_set('', 'v1'));
ok(!$cf->is_set('', 'v2'));
ok($cf->is_set('foo', 'v1'));