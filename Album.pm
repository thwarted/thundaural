
package Album;

# $Header: /home/cvs/thundaural/client/Album.pm,v 1.6 2004/04/08 05:22:43 jukebox Exp $

use strict;
use Albums;
use ClientCommands;
use Track;

sub new {
        my $class = shift;
        my %opts = @_;

        my $this = {};
        bless $this, $class;

        $this->{-albumid} = $opts{-albumid};
	#$this->{iCon} = $main::iCon;
	$this->{-albums} = $opts{-albums};
	$this->_populate();

        return $this;
}

sub _populate {
        my $this = shift;

        return if (!$this->{-albumid});
	my $x = $this->{-albums}->get($this->{-albumid});
	$this->{-info} = $x;
}

sub albumid {
	my $this = shift;
	return $this->{-albumid};
}

sub performer {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{performer};
}

sub name {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{name};
}

sub length {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{length};
}

sub tracks {
	my $this = shift;
	$this->_populate() if (!$this->{-info});

	my $trks = $this->{-albums}->server_connection()->getlist("tracks", $this->{-albumid});
	if (ref($trks) eq 'ARRAY') {
		my $ret = [];
		foreach my $t (@$trks) {
			push(@$ret, new Track(-trackref=>$t->{trackref}, -data=>$t));
		}
		return $ret;
	}
	return [];
}

sub trackids {
	my $this = shift;

	return $this->{-albums}->trackids($this->{-albumid});
}

sub trackrefs {
	my $this = shift;

}

sub coverartfile {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{coverartfile};
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
