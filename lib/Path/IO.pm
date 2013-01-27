package Path::IO;
use strict;
use warnings;

use Path::IO::File;
use Path::IO::Dir;

use Carp;
use Scalar::Util qw/blessed/;
use overload qw//;

use Sub::Exporter::Progressive -setup => {
	exports => [qw/file dir root volume cwd tempdir/],
	groups => {
		defaults => [qw/file dir/],
	},
};

sub file {
	my $arg = shift;
	if (not defined $arg) {
		return;
	}
	elsif (ref($arg) eq 'ARRAY') {
		my @components = @{$arg};
		my $file = pop @components;
		return Path::IO::File->new(dirs => \@components, filename => $file);
	}
	elsif (ref($arg) eq 'HASH') {
		return Path::IO::File->new(%{$arg});
	}
	elsif (ref($arg) && blessed($arg)) {
		if ($arg->isa(__PACKAGE__)) {
			return $arg;
		}
   		elsif (overload::OverloadedStringify($arg)) {
			return file("$arg");
		}
		else {
			croak 'Invalid object given to file';
		}
	}
	else {
		my ($volume, $directories, $file) = File::Spec->splitpath($arg, 0);
		my @directories = File::Spec->splitdir($directories);
		return Path::IO::File->new(volume => $volume, dirs => \@directories, filename => $file, stringified => $arg);
	}
}

sub dir {
	my $arg = shift;
	if (not defined $arg) {
		return;
	}
	elsif (ref($arg) eq 'ARRAY') {
		my @components = @{$arg};
		$components[0] = File::Spec->rootdir if (not @components or $components[0] eq '');
		return Path::IO::Dir->new(dirs => \@components);
	}
	elsif (ref($arg) eq 'HASH') {
		return Path::IO::File->new(%{$arg});
	}
	elsif (ref($arg) && blessed($arg)) {
		if ($arg->isa(__PACKAGE__)) {
			return $arg;
		}
   		elsif (overload::OverloadedStringify($arg)) {
			return dir("$arg");
		}
		else {
			croak 'Invalid object given to dir';
		}
	}
	else {
		my ($volume, $directories, $file) = File::Spec->splitpath($arg, 1);
		my @directories = File::Spec->splitdir($directories);
		pop @directories while @directories > 1 and $directories[-1] eq '';
		return Path::IO::Dir->new(volume => $volume, dirs => \@directories);
	}
}

sub root {
	my %args = @_;
	return Path::IO::Dir->new(%args, dirs => [ File::Spec->rootdir ]);
}

sub volume {
	...;
}

sub cwd {
	my %args = @_;
	return Path::IO::Dir->new(dirs => [ File::Spec->curdir ]);
}

sub tempdir {
	return dir(File::Spec->tmpdir);
}

1;

# ABSTRACT: Modern object oriented paths and IO on them
