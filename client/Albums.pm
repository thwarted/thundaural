
package Albums;

# $Header: /home/cvs/thundaural/client/Albums.pm,v 1.8 2004/01/30 10:16:24 jukebox Exp $

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

	#Logger::logger("%d > %d", $this->{nextupdate}, time());
	my $x = $this->{iCon}->getlist("albums");
	if (ref($x) eq 'ARRAY') {
		$this->{albums} = {};
		foreach my $al (@$x) {
			$al->{coverartfile} = $this->_coverart_localfile($al->{albumid});
			$this->{albums}->{$al->{albumid}} = $al;
		}
		$this->{sorted_performer} = $this->_sort_by('performer', 'name');
	} else {
		$this->{sorted_performer} = [];
		Logger::logger("failed to populate, defaulting to empty list");
	}
	$this->{nextupdate} = time() + 20;
}

sub _sort_by {
	my $this = shift;
	my $how = shift;
	my $how2 = shift;

	if ($how2) {
		return [ sort { ($this->{albums}->{$a}->{$how}.' '.$this->{albums}->{$a}->{$how2} )
				cmp 
				($this->{albums}->{$b}->{$how}.' '.$this->{albums}->{$b}->{$how2} )
			} keys %{$this->{albums}} ];
		
	}

	return [ sort { $this->{albums}->{$a}->{$how} cmp $this->{albums}->{$b}->{$how} } keys %{$this->{albums}} ];
}

sub list {
	my $this = shift;
	my $offset = shift;
	my $limit = shift;

	$this->_populate();
	if (! scalar(keys(%{$this->{albums}})) ) {
		return [];
	}
	# this is some goofy reference trickery here
	# is there a way to do a slice of an array ref through a hash?
	my @x = @{$this->{sorted_performer}};
	if ((scalar @x) > $limit) {
		@x = @x[$offset .. $offset+$limit-1];
	}
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


	my $tmpfile = $this->_coverart_localfile($albumid);
	if (! -s $tmpfile) {
		my $x = $this->{iCon}->coverart($albumid, $tmpfile);
		if (defined($x) && ($tmpfile eq $x)) {
			$this->{albums}->{$albumid}->{coverartfile} = $x;
			return $x;
		}
	}
	return $this->{albums}->{$albumid}->{coverartfile};

	#$this->_populate();
	#return $this->{albums}->{$albumid}->{coverartfile};
}

sub _coverart_localfile {
	my $this = shift;
	my $albumid = shift;

	return sprintf("/tmp/thundaural-coverartcache-album%06d.jpg", $albumid);
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
	}
	Logger::logger("failed to get tracks for $albumid");
	return [];
}

1;
