
package Status;

# $Header: /home/cvs/thundaural/client/Status.pm,v 1.2 2003/12/27 10:46:03 jukebox Exp $

use strict;
use DBI;

use Logger;

use Track;

sub new {
	my $class = shift;
	my %opts = @_;

	my $this = {};
	bless $this, $class;

	$this->{-dbh} = $main::dbh;
	$this->{-outputs} = [];
	$this->{-readers} = [];
	$this->{-queued_on} = {};
	$this->{-updatequeuedon} = {};
	$this->{-lastplaying} = '';

	$this->{iCon} = $opts{Client};

	return $this;
}

sub dump_queued_cache {
	my $this = shift;
	$this->{-queued_on} = {};
}

sub currently_playing {
	my $this = shift;

	my $np = $this->{iCon}->playing_on();
	my $nowplaying = '';
	my $ret = {};
	foreach my $o (keys %$np) {
		my $t = $np->{$o};
		$nowplaying .= ",$o-".$t->{trackid};
		$ret->{$o} = new Track(-trackid=>int($t->{trackid}), -data=>$t);
	}
	if ($nowplaying ne $this->{-lastplaying}) {
		$this->{-queued_on} = {};
	}
	$this->{-lastplaying} = $nowplaying;
	return $ret;
}

sub queued_on {
	my $this = shift;
	my $channel = shift;

	if (exists($this->{-queued_on}->{$channel})) { #  && scalar @{$this->{-queued_on}->{$channel}}) {
		return $this->{-queued_on}->{$channel};
	}

	my $que = $this->{iCon}->getlist('queued', $channel);
	$this->{-queued_on}->{$channel} = $que;
	return $que;

	my $r = [];
	foreach my $t (@$que) {
		my $x = new Track(-trackid=>int($t->{trackid}), -data=>$t);
		push(@$r, $x);
	}
	return $r;
}

sub currently_ripping {
	my $this = shift;

	return {};

#	my $q = "select * from status where name = ?";
#	my $sth = $this->{-dbh}->prepare($q);
#	$sth->execute('trackripping');
#	my $ret = {};
#	while(my $x = $sth->fetchrow_hashref) {
#		#print $x->{devicename}." = ".$x->{value}."\n";
#		$ret->{$x->{devicename}} = $x->{value};
#	}
#	$sth->finish;
#	return $ret;
}

1;

