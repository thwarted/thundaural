
package Albums;

# $Header: /home/cvs/thundaural/client/Albums.pm,v 1.2 2003/12/27 11:47:14 jukebox Exp $

use strict;
use warnings;
use ClientCommands;

sub new {
	my $class = shift;
	my %opts = @_;

	my $this = {};
	bless $this, $class;

	$this->{albums} = {};
	$this->{nextupdate} = 0;
	$this->{sorted_performer} = [];
	$this->{iCon} = $opts{Client} || $opts{-server};

	$this->_populate();

	return $this;
}

sub _populate {
	my $this = shift;

	return if ($this->{albums} && $this->{nextupdate} > time());

	Logger::logger("%d > %d", $this->{nextupdate}, time());
	my $x = $this->{iCon}->getlist("albums");
	if (ref($x) eq 'ARRAY') {
		$this->{albums} = {};
		foreach my $al (@$x) {
			$this->{albums}->{$al->{albumid}} = $al;
		}
		$this->{sorted_performer} = $this->_sort_by('performer');
	} else {
		die("change this to fail gracefully");
	}
	$this->{nextupdate} = time() + 20;
}

sub _sort_by {
	my $this = shift;
	my $how = shift;

	return [ sort { $this->{albums}->{$a}->{$how} cmp $this->{albums}->{$b}->{$how} } keys %{$this->{albums}} ];
}

sub list {
	my $this = shift;
	my $offset = shift;
	my $limit = shift;

	$this->_populate();
	# this is some goofy reference trickery here
	# is there a way to do a slice of an array ref through a hash?
	my @x = @{$this->{sorted_performer}};
	@x = @x[$offset .. $offset+$limit-1];
	return [ @x ];
}

sub get($) {
	my $this = shift;
	my $albumid = shift;

	$this->_populate();
	return $this->{albums}->{$albumid};
}

sub count {
	my $this = shift;
	$this->_populate();
	return scalar(keys(%{$this->{albums}}));
}

sub performer($) {
	my $this = shift;
	my $albumid = shift;

	$this->_populate();
	return $this->{albums}->{$albumid}->{performer};
}

sub name($) {
	my $this = shift;
	my $albumid = shift;

	$this->_populate();
	return $this->{albums}->{$albumid}->{name};
}

sub length($) {
	my $this = shift;
	my $albumid = shift;

	$this->_populate();
	return $this->{albums}-{$albumid}->{length};
}

sub tracks($) {
	my $this = shift;
	my $albumid = shift;

	$this->_populate();
	return $this->{albums}-{$albumid}->{tracks};
}

sub coverartfile($) {
	my $this = shift;
	my $albumid = shift;

	$this->_populate();
	return $this->{albums}->{$albumid}->{coverartfile};
}

sub trackids {
	my $this = shift;
	my $albumid = shift;

	$this->_populate();
	$albumid += 0;
	my $x = $this->{iCon}->getlist("tracks $albumid");
	if (ref($x) eq 'ARRAY') {
		my $ret = [];
		foreach my $t (@$x) {
			push(@$ret, $t->{trackid});
		}
		return $ret;
	} else {
		warn("should fail gracefully");
	}
	return [];
}

1;
