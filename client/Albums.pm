
package Albums;

# $Header: /home/cvs/thundaural/client/Albums.pm,v 1.11 2004/04/08 05:22:43 jukebox Exp $

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
	$this->{-tmpdir} = $opts{-tmpdir};

	$this->_populate();

	return $this;
}

sub server_connection {
	my $this = shift;
	return $this->{iCon};
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
		$this->{sorted_performer} = $this->_sort_by('sortname', 'name');
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

	return sprintf('%s/thundaural-coverartcache-album%06d.jpg', $this->{-tmpdir}, $albumid);
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

#    Thundaural Jukebox
#    Copyright (C) 2003-2004  Andrew A. Bakun
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
