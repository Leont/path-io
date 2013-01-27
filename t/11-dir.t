#! perl

use strict;
use warnings;

use File::Spec::Functions qw/catpath catdir curdir rootdir/;
use Test::More 0.89;
use Path::IO qw/file dir root cwd/;
use Perl::OSType 'is_os_type';

my $dir = dir('tmp');
is($dir, 'tmp');
ok($dir->is_relative);
#is($dir->basename, 'tmp');
 
my $dir2 = dir('/tmp');
is($dir2, '/tmp');
is($dir2->is_absolute, 1);
 
my $cat = file([$dir, 'foo']);
is($cat, 'tmp/foo');
$cat = $dir->file('foo');
is($cat, 'tmp/foo');
is($cat->parent, 'tmp');
is($cat->filename, 'foo');
 
$cat = file([$dir2, 'foo']);
is($cat, '/tmp/foo');
$cat = $dir2->file('foo');
is($cat, '/tmp/foo');
ok($cat->isa('Path::IO::File'));
is($cat->parent, '/tmp');
 
$cat = $dir2->dir('foo');
is($cat, '/tmp/foo');
ok($cat->isa('Path::IO::Dir'));
#is($cat->basename, 'foo');
 
TODO: {
	my $dir = dir('/foo/bar/baz');
	is($dir->parent, '/foo/bar') or diag explain $dir, $dir->parent;
	is($dir->parent->parent, '/foo');
	is($dir->parent->parent->parent, '/');
	is($dir->parent->parent->parent->parent, '/', 'parent of "/" is "/"');
 
	$dir = dir('foo/bar/baz');
	is($dir->parent, 'foo/bar');
	is($dir->parent->parent, 'foo');
	is($dir->parent->parent->parent, '.');
	is($dir->parent->parent->parent->parent, '..');
	is($dir->parent->parent->parent->parent->parent, '../..');
};
 
{
	my $dir = dir("foo/");
	is($dir, 'foo');
	is($dir->parent, '.') or diag explain $dir;
}
 
{
	# Special cases
	is(root, '/');
	is(cwd, '.');
	is(dir([root, 'var', 'tmp']), '/var/tmp');
	is(cwd->absolute->resolve, dir(Cwd::cwd())->resolve);
	is(dir(undef), undef);
}
 
{
	# Test is_dir()
	is(dir('foo')->is_dir, 1);
	is(file('foo')->is_dir, 0);
}
 
TODO: {
	# subsumes()
	ok(dir('foo/bar')->subsumes('foo/bar/baz'));
	ok(dir('/foo/bar')->subsumes('/foo/bar/baz'));
	ok(not dir('foo/bar')->subsumes('bar/baz'));
	ok(not dir('/foo/bar')->subsumes('foo/bar'));
	ok(not dir('/foo/bar')->subsumes('/foo/baz'));
	ok(dir('/')->subsumes('/foo/bar'));
}

done_testing;
