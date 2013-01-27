package Path::IO::Role::Entity;

use Moo::Role;

use Carp;
use File::Spec;
use File::stat qw//;
use Sub::Name;

has _implementation => (
	is       => 'ro',
	init_arg => 'implementation',
	default  => sub {
		return 'File::Spec';
	},
);

has volume => (
	is       => 'ro',
	required => 1,
);

has parent => (
	is       => 'lazy',
	required => 1,
	init_arg => undef,
);

has stringified => (
	is       => 'lazy',
	required => 1,
);

has is_absolute => (
	is      => 'ro',
	default => sub {
		my $self = shift;
		return $self->_implementation->file_name_is_absolute($self->stringified);
	},
	predicate => '_has_absolute'
);

sub is_relative {
	my $self = shift;
	return not $self->is_absolute;
}

sub remove {
	my ($self, %args) = @_;
	require File::Path;
	return File::Path::remove_tree($self->stringified, \%args);
}

requires qw/absolute relative cleanup resolve readlink basename/;

for my $stat (qw/dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks/) {
	no strict 'refs';
	*{$stat} = subname($stat, sub { my $self = shift; $self->stat->$stat });
}

sub stat {
	my $self = shift;
	return File::stat::stat($self->stringified);
}
sub lstat {
	my $self = shift;
	return File::stat::lstat($self->stringified);
}
1;
