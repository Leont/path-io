package Path::IO::Dir;

use Moo;

with 'Path::IO::Role::Entity';

use Carp qw//;
use List::MoreUtils qw//;

use overload
	q{""}    => sub { $_[0]->stringified },
	bool     => sub { 1 },
	fallback => 1;

has '_components' => (
	is => 'ro',
	required => 1,
	init_arg => 'dirs',
);

has '+volume' => (
	default => sub { '' },
);

sub _get_parent {
	my $self = shift;
	my @components = @{ $self->_components };
	
	my ($curdir, $updir) = map { $self->_implementation->$_ } qw/curdir updir/;
	if ($self->is_absolute) {
		pop @components unless @components == 1 && $components[0] eq '';
		return (volume => $self->volume, dirs => [ @components ], is_absolute => 1);
	}
	elsif (@components == 0 or $self->stringified eq $curdir) {
		return (dirs => [ $updir ], is_absolute => 0);
	}
	elsif (List::MoreUtils::all { $_ eq $updir } @components) {
		return (dirs => [ $updir, @components ], is_absolute => 0);
	}
	elsif (@components == 1) {
		return (dirs => [ $curdir ], is_absolute => 0);
	}
	else {
		pop @components;
		return (dirs => [ @components ], is_absolute => 0);
	}
}

has '+parent' => (
	default  => sub {
		my $self = shift;
		return Path::IO::Dir->new($self->_get_parent);
	},
);

sub is_dir {
	return 1;
}

sub _build_stringified {
	my $self = shift;
	if ($self->is_absolute) {
		my $dirs = $self->_implementation->catdir(@{ $self->_components });
		return $self->_implementation->catpath($self->volume, $dirs, '');
	}
	else {
		return $self->_implementation->catdir(@{ $self->_components });
	}
}

sub file {
	my ($self, $filename) = @_;
	my %extra = $self->_has_absolute ? ( is_absolute => $self->is_absolute ) : ();
	return Path::IO::File->new(
		implementation => $self->_implementation,
		volume         => $self->volume,
		dirs           => [ @{ $self->_components } ],
		filename       => $filename,
		parent         => $self,
		%extra,
	);
}

sub dir {
	my ($self, $dirname) = @_;
	my %extra = $self->_has_absolute ? ( is_absolute => $self->is_absolute ) : ();
	return Path::IO::Dir->new(
		implementation => $self->_implementation,
		volume         => $self->volume,
		dirs           => [ @{ $self->_components }, $dirname ],
		parent         => $self,
		%extra,
	);
}

sub make_path {
	my ($self, %args) = @_;
	require File::Path;
	return File::Path::make_path($self->stringified, \%args);
}

sub tempfile {
	my ($self, @args) = @_;
	require File::Temp;
	return File::Temp::tempfile(@args, DIR => $self->stringified);
}
sub open {
	my $self = shift;
	my $dirname = $self->stringified;
	opendir my ($dh), $dirname or Carp::croak("Could not open dir '$dirname': $!");
	return $dh;
}
#sub all;

sub subsumes {
	my ($self, $other) = @_;
	die "No second entity given to subsumes()" unless $other;
	
	if (not ref $other or not $other->isa(__PACKAGE__)) {
		my ($volume, $dirs) = $self->_implementation->splitpath($other, 1);
		my @dirs = $self->_implementation->splitdir($dirs);
		$other = Path::IO::Dir->new(
			implementation => $self->_implementation,
			dirs => \@dirs,
		);
	}
	
	if ($self->is_absolute) {
		$other = $other->absolute;
	} elsif ($other->is_absolute) {
		$self = $self->absolute;
	}
 
	$self = $self->cleanup;
	$other = $other->cleanup;
 
	if ($self->volume) {
		return unless $self->volume eq $other->volume;
	}
 
	# The root dir subsumes everything (but ignore the volume because
	# we've already checked that)
	return 1 if $self->stringified eq $self->_implementation->rootdir;

	my @self_dirs = @{ $self->_components };
	my @other_dirs = @{ $other->_components };
	for my $i (0 .. $#self_dirs) {
		return if $i >= @other_dirs;
		return if $self_dirs[$i] ne $other_dirs[$i];
	}
	return 1;
}

sub contains {
	my ($self, $other) = @_;
	return !!(-d $self and (-e $other or -l $other) and $self->subsumes($other));
}

sub readlink {
	my ($self, $base) = @_;
	return $self if $self->is_absolute;


	my $newpath = $self->_implementation->rel2abs($self->stringified, $base);
	my ($volume, $dirs) = $self->_implementation->splitpath($newpath, 1);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::Dir->new(volume => $volume, dirs => \@dirs);
}

sub absolute {
	my ($self, $base) = @_;
	return $self if $self->is_absolute;

	my $newpath = $self->_implementation->rel2abs($self->stringified, $base);
	my ($volume, $dirs) = $self->_implementation->splitpath($newpath, 1);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::Dir->new(volume => $volume, dirs => \@dirs);
}

sub relative {
	my ($self, $base) = @_;
	return $self if not $self->is_absolute and not defined $base;

	my $newpath = $self->_implementation->abs2rel($self->stringified, $base);
	my (undef, $dirs) = $self->_implementation->splitpath($newpath, 1);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::Dir->new(dirs => \@dirs);
}

sub cleanup {
	my ($self) = @_;

	my $newpath = $self->_implementation->canonpath($self->stringified);
	my ($volume, $dirs) = $self->_implementation->splitpath($newpath, 1);
	my @dirs = $self->_implementation->splitdir($dirs);
	return Path::IO::Dir->new(volume => $volume, dirs => \@dirs);
}

sub resolve { 
	my ($self, $base) = @_;

	Carp::croak('Can\'t resolve for foreign path') if not File::Spec->isa($self->_implementation);
	my $newpath = Cwd::realpath($self->stringified);
	my ($volume, $dirs, $file) = $self->_implementation->splitpath($newpath, 1);
	my @dirs = $self->_implementation->splitdir($dirs);
	my $ret = Path::IO::Dir->new(volume => $volume, dirs => \@dirs);
	return $self->is_absolute ? $ret : $ret->relative($base);
}

sub basename;

1;

