#!/usr/bin/perl

# Currently, only one ripping device is supported
# this code assumes there is only one

package Layout;

# $Header: /home/cvs/thundaural/client/Layout.pm,v 1.2 2003/12/27 10:43:07 jukebox Exp $

use strict;
use DBI;

sub new {
	my $class = shift;
	my %opts = @_;

	my $this = {};
	bless $this, $class;

	$this->{-dbh} = $main::dbh;
	$this->{iCon} = $opts{Client} || $opts{-server};
	$this->_populate();

	return $this;
}
	                                                                                                                                                                     
sub _populate {
	my $this = shift;

	my $dl = $this->{iCon}->getlist('devices');
	foreach my $d (@$dl) {
		$this->{$d->{type}} = [] if (ref($this->{$d->{type}}) ne 'ARRAY');
		push(@{$this->{$d->{type}}}, $d);
	}
}

sub storagedir {
	my $this = shift;
	return '/home/storage';
}

sub outputs {
	my $this = shift;
	my $ret = [];
	foreach my $x (@{$this->{play}}) {
		push(@$ret, $x->{'device-name'});
	}
	return $ret;
}

sub cycle_outputs {
	my $this = shift;
	my $cur = shift;

	my $out = $this->outputs();
	my $out = [ @$out, @$out ]; # last + 1 will now equal first
	my $ret;
	my $takenext = 0;
	foreach my $o (@$out) {
		return $o if ($takenext);
		$takenext = 1 if ($o eq $cur);
	}
	return $out->[0];
}

sub _rip_device {
	my $this = shift;
	return $this->{read}->[0]->{'device-name'};
}

sub start_rip {
	my $this = shift;
	my $sth;
	my $q;

	my($package, $filename, $line) = caller;
	warn("$filename:$line ($package) called Layout::start_rip");
	return 0;

	my $devicename = $this->_rip_device; # we only support one rip device right now
	return if (!$devicename);

	my $cp = $this->ripping_progress();
	return if ($cp->{$devicename});

	$cp = $this->ripping_started();
	return if ($cp->{$devicename});

	$q = 'insert into status (name, devicename) values (?, ?)';
	$sth = $this->{-dbh}->prepare($q);
	$sth->execute('startrip', $devicename);
	$sth->finish;
}

#sub _progress {
#	my $this = shift;
#	my $devicename = shift;
#	my $which = shift;
#
#	my $q = "select * from status where name = ?";
#	my @a = ($which);
#	if ($devicename) {
#		$q .= " and devicename = ?";
#		push(@a, $devicename);
#	}
#	my $sth = $this->{-dbh}->prepare($q);
#	$sth->execute(@a);
#	my $ret = {};
#        while(my $x = $sth->fetchrow_hashref) {
#		delete $x->{name};
#                $ret->{$x->{devicename}} = $x;
#        }
#	$sth->finish;
#	return $ret;
#}
#
#sub playing_progress {
#	my $this = shift;
#	my $devicename = shift;
#	my($package, $filename, $line) = caller;
#	warn("$filename:$line ($package) called Layout::playing_progress");
#	return $this->_progress($devicename, 'trackplaying');
#}
#
#sub ripping_progress {
#	my $this = shift;
#	my $devicename = shift;
#	my($package, $filename, $line) = caller;
#	warn("$filename:$line ($package) called Layout::playing_progress");
#	return $this->_progress($devicename, 'trackripping');
#}
#
#sub ripping_started {
#	my $this = shift;
#	my $devicename = shift;
#	my($package, $filename, $line) = caller;
#	warn("$filename:$line ($package) called Layout::playing_progress");
#	return $this->_progress($devicename, 'startrip');
#}

1;

