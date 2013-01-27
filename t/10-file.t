#! perl

use strict;
use warnings;

use File::Spec::Functions qw/catpath catdir curdir rootdir/;
use Test::More 0.89;
use Path::IO qw/file dir/;
use Perl::OSType 'is_os_type';

my $file1 = Path::IO::File->new(filename => 'foo.txt');
is($file1, 'foo.txt', 'Stringifies to "foo.txt"');
ok($file1->is_relative, 'Is relative');
is($file1->parent, '.', 'Parent is "."');
is($file1->filename, 'foo.txt', 'filename is "foo.txt"');
 
my $file2 = file(['dir', 'bar.txt']);
is($file2, catpath('', 'dir', 'bar.txt'), 'Stringifies to "dir/bar"');
ok($file2->is_relative, 'Is relative 2');
is($file2->parent, 'dir', 'parent is "dir"');# or diag explain $file2;
is($file2->filename, 'bar.txt', 'filename is "bar.txt"');

my $loc = catpath('', catdir(rootdir, qw/foo baz/, curdir), 'foo');
my $file = file($loc)->cleanup;
is($file, '/foo/baz/foo', 'Stringifies to "/foo/baz/foo" after cleanup');
is($file->parent, '/foo/baz', 'Cleaned up parent is "/foo/baz"');
 
if (is_os_type('Unix')) {
	my $file = file('/tmp/foo/bar.txt');
	is($file->relative('/tmp'), 'foo/bar.txt');
	is($file->relative('/tmp/foo'), 'bar.txt');
	is($file->relative('/tmp/'), 'foo/bar.txt');
	is($file->relative('/tmp/foo/'), 'bar.txt');
 
	$file = file('one/two/three');
	is($file->relative('one'), 'two/three') or diag explain $file, $file->relative('one');
}

done_testing;
