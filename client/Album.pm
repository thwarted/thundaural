
package Album;

# $Header: /home/cvs/thundaural/client/Album.pm,v 1.3 2004/01/09 06:01:47 jukebox Exp $

use strict;
use Albums;
use ClientCommands;
use Track;

my $iCon;

sub new {
        my $class = shift;
        my %opts = @_;

        my $this = {};
        bless $this, $class;

        $this->{-albumid} = $opts{-albumid};
	$this->{iCon} = $main::iCon;
	$this->_populate();

        return $this;
}

sub _populate {
        my $this = shift;

        return if (!$this->{-albumid});
	my $x = $main::Albums->get($this->{-albumid});
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

	my $trks = $this->{iCon}->getlist("tracks", $this->{-albumid});
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

	return $main::Albums->trackids($this->{-albumid});
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

__END__
#sub count {
#	my $q = "select count(1) from albums";
#	my $sth = $main::dbh->prepare($q);
#	$sth->execute;
#	my ($c) = $sth->fetchrow_array;
#	$sth->finish;
#	return $c;
#}

sub ranking {
	my $this = shift;

	my $q;
	my $table = "rank$$";
	my $sth;

	$q = "drop table if exists $table";
	eval {
		$this->{-dbh}->do($q);
	};

	$q = 'set @rank := 0';
	eval {
		$this->{-dbh}->do($q);
	};
	$q = "create temporary table $table as 
		select count(1) as c, 
			a.albumid as albumid,
			\@rank := \@rank + 1 as rank 
		from albums a left join tracks t 
			on t.albumid = a.albumid 
			left join playhistory p 
			on p.trackid = t.trackid 
		where p.action = 'played' 
		group by 2 order by 1 desc";
	eval {
		$this->{-dbh}->do($q);
	};

	$q = "select rank from $table where albumid = ?";
	my $rank;
	eval {
		$sth = $this->{-dbh}->prepare($q);
		$sth->execute($this->{-albumid});
		($rank) = $sth->fetchrow_array;
		$rank = 0 if (!defined($rank));
		$sth->finish;
	};

	$q = "select \@rank";
	my $total;
	eval {
		$sth = $this->{-dbh}->prepare($q);
		$sth->execute;
		($total) = $sth->fetchrow_array;
		$sth->finish;
	};

	$q = "drop table if exists $table";
	eval {
		$this->{-dbh}->do($q);
	};

	return ($rank, $total);
}

#sub riptime {
#	my $this = shift;
#	$this->_populate() if (!$this->{-info});
#	return $this->{-info}->{riptime};
#}

#sub cddbid {
#	my $this = shift;
#	$this->_populate() if (!$this->{-info});
#	return $this->{-info}->{cddbid};
#}

