
package Track;

# $Header: /home/cvs/thundaural/client/Track.pm,v 1.5 2004/04/08 05:22:43 jukebox Exp $

use strict;
use Album;

use Logger;

sub new {
	my $class = shift;
	my %opts = @_;

	my $this = {};
	bless $this, $class;

	$this->{-trackid} = $opts{-trackid};
	$this->{-trackref} = $opts{-trackref};

	$this->{iCon} = $main::iCon;

	$this->{-info} = $opts{-data};
	$this->_populate();

	return $this;
}

sub _populate {
	my $this = shift;

	return if ($this->{-info});
	my $t = $this->{-trackref} ? $this->{-trackref} : $this->{-trackid};
	return undef if (!$t);
	my $x = $this->{iCon}->getlist("track", $t);
	my $x = shift @$x;
	$this->{-info} = $x;
	Logger::logger("Got trackinfo:");
	foreach my $k (keys %{$this->{-info}}) {
		Logger::logger("\t$k = ".$this->{-info}->{$k});
	}
	$this->{-trackid} = $this->{-info}->{trackid};
	$this->{-trackref} = $this->{-info}->{trackref};

	1;
}

sub play {
	my $this = shift;
	my $devicename = shift;

	return undef if (!$devicename); # we don't use this right now
	my $t = $this->{-trackref} ? $this->{-trackref} : $this->{-trackid};
	return undef if (!$t);
	return $this->{iCon}->play($t, $devicename);
}

sub popularity {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{popularity};
}

sub rank {
	my $this = shift;

	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{rank};

}

sub trackid {
	my $this = shift;
	return $this->{-trackid};
}

sub trackref {
	my $this = shift;
	return $this->{-trackref};
}

sub performer {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{performer};
}

sub albumid {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{albumid};
}

sub length {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{length};
}

sub name {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{name};
}

sub albumorder {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{albumorder};
}

sub genre {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{genre};
}

sub started { # only for currently playing tracks
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{started};
}

sub requestedat {
	my $this = shift;
	$this->_popuplate() if (!$this->{-info});
	return $this->{-info}->{requestedat};
}

sub current { # only for currently playing tracks
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{current} || 0;
}

sub percentage { # only for currently playing tracks
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{percentage} || 0;
}

sub filename {
	my $this = shift;
	$this->_populate() if (!$this->{-info});
	return $this->{-info}->{filename};
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

__END__

# rank calculation
#	my $q;
#	my $table = "rank$$";
#	my $sth;
#
#	$q = "drop table if exists $table";
#	eval {
#		$this->{-dbh}->do($q);
#	};
#
#	$q = 'set @rank := 0';
#	eval {
#		$this->{-dbh}->do($q);
#	};
#	$q = "create temporary table $table as 
#		select count(1) as c, 
#			trackid, 
#			\@rank := \@rank + 1 as rank 
#		from playhistory 
#		where action = 'played' 
#		group by 2 order by 1 desc";
#	eval {
#		$this->{-dbh}->do($q);
#	};
#
#	$q = "select rank from $table where trackid = ?";
#	my $rank;
#	eval {
#		$sth = $this->{-dbh}->prepare($q);
#		$sth->execute($this->{-trackid});
#		($rank) = $sth->fetchrow_array;
#		$rank = 0 if (!defined($rank));
#		$sth->finish;
#	};
#
#	$q = "select \@rank";
#	my $total;
#	eval {
#		$sth = $this->{-dbh}->prepare($q);
#		$sth->execute;
#		($total) = $sth->fetchrow_array;
#		$sth->finish;
#	};
#
#	$q = "drop table if exists $table";
#	eval {
#		$this->{-dbh}->do($q);
#	};
#
#	return ($rank, $total);

sub last {
	my $this = shift;
	my $action = shift || "played";
	my $t = $this->{-trackref} ? $this->{-trackref} : $this->{-trackid};
	return undef if (!$t);
	return $this->{-info}->{"last-$action"}

#	my $q = "select max(actedat) as `date`, 
#			unix_timestamp(max(actedat)) as `unixdate`, 
#			unix_timestamp()-unix_timestamp(max(actedat)) as `secondsago`,
#			sec_to_time(unix_timestamp()-unix_timestamp(max(actedat))) as `timeago`
#			from playhistory where trackid = ? and action = ?";
#	my $sth = $this->{-dbh}->prepare($q);
#	$sth->execute($this->{-trackid}, $action);
#	my $when = $sth->fetchrow_hashref;
#	$sth->finish;
#	return $when;
}

sub times {
	my $this = shift;
	my $action = shift || "played";
	my $t = $this->{-trackref} ? $this->{-trackref} : $this->{-trackid};
	return undef if (!$t);
	return $this->{-info}->{"times-$action"};

#	my $q = "select count(1) from playhistory where trackid = ? and action = ?";
#	my $sth = $this->{-dbh}->prepare($q);
#	$sth->execute($this->{-trackid}, $action);
#	my ($c) = $sth->fetchrow_array;
#	$sth->finish;
#	return $c;
}

# popularity calculation
#	return undef if (!$this->{-trackid});
#	my $sth;
#	my $q;
#	$q = "select count(1) from playhistory where action = 'played' and trackid = ?";
#	$sth = $this->{-dbh}->prepare($q);
#	$sth->execute($this->{-trackid});
#	my ($t) = $sth->fetchrow_array;
#	$sth->finish;
#	return undef if ($t == 0); # never played
#
#	$q = "select count(1) from playhistory where action = 'played'";
#	$sth = $this->{-dbh}->prepare($q);
#	$sth->execute;
#	my ($c) = $sth->fetchrow_array;
#	$sth->finish;
#	return undef if ($c == 0); # nothing ever played
#
#	return ($t/$c)*100;
