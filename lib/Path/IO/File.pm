package Path::IO::File;

use Moo;
use FileHandle;

with 'Path::IO::Role::Entity';

use Carp qw//;

use overload
	q{""}    => sub { $_[0]->stringified },
	bool     => sub { 1 },
	fallback => 1;

has '+volume' => (
	default => sub { },
);

has filename => (
	is       => 'ro',
	required => 1,
);

has _directory_components => (
	is       => 'ro',
	required => 1,
	init_arg => 'dirs',
	default  => sub { [] },
);

has '+parent' => (
	default  => sub {
		my $self = shift;
		my @components = @{ $self->_directory_components };
		@components = $self->_implementation->curdir if not @components and $self->is_relative;
		my %extra = $self->_has_absolute ? ( is_absolute => $self->is_absolute ) : ();
		return Path::IO::Dir->new(
			implementation => $self->_implementation,
			volume         => $self->volume,
			dirs           => \@components,
			%extra,
		);
	},
);

sub _build_stringified {
	my $self = shift;
	my @components = @{ $self->_directory_components };
	if ($self->is_absolute) {
		my $dirs = $self->_implementation->catdir(@components);
		return $self->_implementation->catpath($self->volume, $dirs, $self->filename);
	}
	else {
		return $self->_implementation->catfile(@components, $self->filename);
	}
}

sub is_dir {
	return 0;
}

sub open {
	my ($self, $mode) = @_;
	my $filename = $self->stringify;
	CORE::open my $fh, $mode, $filename or Carp::croak("Couldn't open $filename: $!");
	return $fh;
}

sub slurp {
	my ($self, @args) = @_;
	my $filename = $self->stringified;
	require File::Slurp;
	return File::Slurp::read_file($filename, @args);
}

sub spew {
	my ($self, @args) = @_;
	my $filename = $self->stringified;
	require File::Slurp;
	return File::Slurp::spew_file($filename, @args);
}

sub touch {
	my $self = shift;
	my $filename = $self->stringify;
	if (-e $filename) {
		my $now = time;
		utime $now, $now, $filename or Carp::croak("Could not touch $filename: $!");
	}
	else {
		CORE::open my $fh, '>:raw', $filename or Carp::croak("Could not open $filename; $!");
		close $fh or Carp::croak("Could not close $filename: $!");
	}
	return;
}

sub readlink {
	my ($self, $base) = @_;
	return $self if $self->is_absolute;


	my $newpath = $self->_implementation->rel2abs($self->stringified, $base);
	my ($volume, $dirs, $file) = $self->_implementation->splitpath($newpath, 0);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::File->new(volume => $volume, dirs => \@dirs, filename => $file);
}

sub absolute {
	my ($self, $base) = @_;
	return $self if $self->is_absolute;

	my $newpath = $self->_implementation->rel2abs($self->stringified, $base);
	my ($volume, $dirs, $file) = $self->_implementation->splitpath($newpath, 0);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::File->new(volume => $volume, dirs => \@dirs, filename => $file);
}

sub relative {
	my ($self, $base) = @_;
	return $self if not $self->is_absolute and not defined $base;

	my $newpath = $self->_implementation->abs2rel($self->stringified, $base);
	my (undef, $dirs, $file) = $self->_implementation->splitpath($newpath, 0);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::File->new(dirs => \@dirs, filename => $file);
}

sub cleanup {
	my ($self, $base) = @_;

	my $newpath = $self->_implementation->canonpath($self->stringified);
	my ($volume, $dirs, $file) = $self->_implementation->splitpath($newpath);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::File->new(volume => $volume, dirs => \@dirs, filename => $file);
}

sub resolve { 
	my ($self, $base) = @_;

	Carp::croak('Can\'t resolve for foreign path') if not File::Spec->isa($self->_implementation);
	my $newpath = Cwd::realpath($self->stringified);
	my ($volume, $dirs, $file) = $self->_implementation->splitpath($newpath, $self->is_dir);
	my @dirs = $self->_implementation->splitdir($dirs);
	my $ret = Path::IO::File->new(volume => $volume, dirs => \@dirs, filename => $file);
	return $self->is_absolute ? $ret : $ret->relative;
}

sub basename;

1;
