#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/TARipLookupFreeDB.pm,v 1.3 2004/03/27 08:58:47 jukebox Exp $

package TARipLookupFreeDB;

use Data::Dumper;

use strict;
use warnings;

use TARipUtil;

my $tmpdir = "/var/tmp";

use CDDB_get qw( get_cddb );

sub new {
	my $proto = shift;
        my %o = @_;

        my $class = ref($proto) || $proto;
	my $this = {};
	bless $this, $class;
	$this->{storagedir} = $o{storagedir};
	$this->{cddevice} = $o{cddevice};
	die(sprintf("%s: must pass cddevice to constructor\n", __PACKAGE__)) if (!$this->{cddevice});
	$this->{bin_cdda2wav} = $o{cdda2wav} || $this->find_cdda2wav();
	die(sprintf("%s: cddevice inaccessible\n", __PACKAGE__)) if (!(-r $this->{cddevice}));
	die(sprintf("%s: cdda2wav inaccessible\n", __PACKAGE__)) if (!(-x $this->{bin_cdda2wav}));
	return $this;
}

sub lookup {
	my $this = shift;
	my %s = @_;
        my %cddbconf;

	my $cddevice = $this->{'cddevice'};
	die(sprintf('%s: %s', __PACKAGE__, "missing cdrom device to read"))
		unless ($cddevice);
	my @tlens = $this->get_track_lengths($cddevice);

	my $cdids = $this->get_cdids();

        $cddbconf{'CDDB_HOST'} = "freedb.freedb.org"; # set cddb host
        $cddbconf{'CDDB_PORT'} = 8880; # set cddb port
        $cddbconf{'CDDB_MODE'} = "cddb"; # set cddb mode: cddb or http
	$cddbconf{'CD_DEVICE'} = $cddevice; 
	$cddbconf{'input'} = 0; # no interaction

	my %cd;
	eval {
		%cd = get_cddb(\%cddbconf);
	};
	die(sprintf("%s: failed to get album info: %s\n", __PACKAGE__, $@)) if (!$cd{'id'});
	my $cd = {%cd};
	my $tracks = [];
	foreach my $t (@{$cd->{track}}) {
		my $ti = {};
		$ti->{'trackname'} = TARipUtil::strcleanup($t);
		$ti->{'performer'} = TARipUtil::strcleanup($cd->{artist});
		$ti->{'performersort'} = TARipUtil::strcleanup($this->mksortname($cd->{artist}));
		$ti->{'sectors'} = TARipUtil::strcleanup(shift @tlens);
		$ti->{'length'} = int($ti->{'sectors'} / 75);
		push(@$tracks, $ti);
	}

	return {tracks=>$tracks,
		cdindexid=>$cdids->{cdindexid},
		cddbid=>TARipUtil::strcleanup($cd{id}),
		source=>'FreeDB',
		numtracks=>(scalar @$tracks),
		totaltime=>$cdids->{totaltime},
		album=>{
		   	performer=>TARipUtil::strcleanup($cd->{artist}),
		   	performersort=>TARipUtil::strcleanup($this->mksortname($cd->{artist})),
			albumname=>TARipUtil::strcleanup($cd->{title})
		   	}
		};
}

sub fixup_str {
	my $str = shift;

	$str =~ s/^\s+//g;
	$str =~ s/\s+$//g;
	$str =~ s/\s+/ /g;
	return $str;
}

sub get_track_lengths {
	my $this = shift;
	my $device = shift;
	my $cdda2wav = `which cdda2wav 2>/dev/null`; 
	chomp $cdda2wav;
	die(sprintf("%s: unable to find cdda2wav in path", __PACKAGE__)) 
		unless ($cdda2wav);
	open(C2W, "( $cdda2wav --device $device -N -J -v toc 2>&1 ) |");
	my @x = <C2W>;
	close(C2W);
	my $x = join('', @x);
	$x =~ s/,/\n/sg;
	@x = split(/\n+/, $x);
	my @lens = ();
	while(my $line = shift @x) {
		if (my($min,$sec,$set) = $line =~ /^\s*\d+\.\(\s*(\d+):(\d+)\.(\d+)\)\s*$/) {
			push(@lens, ($min*60*75)+($sec*75)+$set);
		}
	}
	return @lens;
}

sub mksortname {
	my $this = shift;
	my $a = shift;

	$a =~ s/^\s+//;
	$a =~ s/^(An?\W|The\W|\W+)//i;
	return lc $a;
}

sub find_cdda2wav {
	my $this = shift;
	my $px = `which cdda2wav 2>/dev/null`;
	chomp $px;
	return $px if ($px);
	die(sprintf("%s: unable to find cdda2wav in path\n", __PACKAGE__));
}

sub get_cdids {
	my $this = shift;
                                                                                                                                                                                 
        my $tfile = TARipUtil::mymktempname($this->{storagedir}, $this->{cddevice}, 'discinfo.freedb');
	my $cmd = sprintf('%s --device %s -N -J -v toc,sectors > %s 2>&1', $this->{bin_cdda2wav}, $this->{cddevice}, $tfile);
	system($cmd);

        open(C2W, "<$tfile");
	my @output = <C2W>;
	close(C2W);
        unlink($tfile);

	my(@x, $discidline);
	my($cdindexid, $cddbid, $numtracks, $totaltime);

	@x = grep(/^CDINDEX discid: /, @output);
	if (@x) {
		$discidline = shift @x;
		($cdindexid) = $discidline =~ m/^CDINDEX discid: (.+)$/;
	}

	@x = grep(/^CDDB discid: /, @output);
	if (@x) {
		$discidline = shift @x;
		($cddbid) = $discidline =~ m/^CDDB discid: 0x([0-9a-f]+)$/;
	}

	@x = grep(/^Table of Contents: total tracks:/, @output);
	if (@x) {
        	my $ntline = shift @x;
		($numtracks,$totaltime) = $ntline =~ /^Table of Contents: total tracks:(\d+),.*total time ([0-9:.]+)/;
		my($mins,$secs,undef,$ss) = $totaltime =~ m/^(\d+):(\d+)(.(\d+))?$/;
		$totaltime = ($mins * 60) + ($secs) + ($ss ? 1 : 0);
	}

	die(sprintf("%s: failed to get all information\n", __PACKAGE__)) if (!$cdindexid || !$cddbid);

	return {cdindexid=>$cdindexid, cddbid=>$cddbid, totaltime=>$totaltime};
}

1;
