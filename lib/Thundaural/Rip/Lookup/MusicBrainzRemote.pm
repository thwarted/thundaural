#!/usr/bin/perl

package Thundaural::Rip::Lookup::MusicBrainzRemote;

use strict;
use warnings;

use Data::Dumper;
use XML::Ximple;
use LWP::UserAgent;

use Thundaural::Util;

sub new {
	my $proto = shift;
	my %o = @_;

	my $class = ref($proto) || $proto;
	my $this = {};
	bless $this, $class;
	$this->{storagedir} = $o{storagedir} || '/tmp';
	$this->{cddevice} = $o{cddevice};
	$this->{bin_cdda2wav} = $o{cdda2wav} || $this->find_cdda2wav();
	$this->{albuminfo} = {};
	$this->{artists} = {};
	die(sprintf("%s: must pass cddevice to constructor\n", __PACKAGE__)) if (!$this->{cddevice});
	die(sprintf("%s: cddevice inaccessible\n", __PACKAGE__)) if (!(-r $this->{cddevice}));
	die(sprintf("%s: cdda2wav inaccessible\n", __PACKAGE__)) if (!(-x $this->{bin_cdda2wav}));
	return $this;
}

sub find_cdda2wav {
	my $this = shift;
	my $px = `which cdda2wav 2>/dev/null`;
	chomp $px;
	return $px if ($px);
	die(sprintf("%s: unable to find cdda2wav in path\n", __PACKAGE__));
}

sub lookup {
	my $this = shift;

	my $cdinfo = $this->get_cd_info();
	my $cdindexid = $cdinfo->{cdindexid};
	my @tlens = @{$cdinfo->{tracklens}};

	my $xml = $this->get_xml($cdindexid);
	my $tree = XML::Ximple::parse_xml($xml);

	$this->{albuminfo} = {
		'creator'=>undef,
		'artist'=>undef,
		'gid'=>undef,
		'tracks'=>[],
	};

	eval {
		$this->process_tree('tree'=>$tree);
	};
	warn($@) if ($@);

	# no tracks found -- must not be in the database
	if (!(scalar @{$this->{albuminfo}->{tracks}})) {
		return undef;
	}

	my $ret = [];

	foreach my $t (@{$this->{albuminfo}->{tracks}}) {
		my $ti = {};
		$ti->{'trackname'} = $t->{name};
		$ti->{'performer'} = $this->{artists}->{$t->{creator}}->{name};
		$ti->{'performersort'} = lc $this->{artists}->{$t->{creator}}->{sortname};
		$ti->{'sectors'} = shift @tlens;
		$ti->{'length'} = int($ti->{'sectors'} / 75);
		push(@$ret, $ti);
	}
	return {tracks=>$ret,
		cdindexid=>$cdinfo->{cdindexid},
		cddbid=>$cdinfo->{cddbid},
		source=>'MusicBrainzRemote',
		numtracks=>$cdinfo->{numtracks},
		totaltime=>$cdinfo->{totaltime},
		album=>{
			performer=>$this->{albuminfo}->{artist}->{name},
			performersort=>lc ($this->{albuminfo}->{artist}->{sortname}),
			albumname=>$this->{albuminfo}->{name}
			}
		};
}

sub get_cd_info {
	my $this = shift;
	#Table of Contents: total tracks:11, (total time 50:14.72)
	# CDINDEX discid: zP9XT1MCijZ7lWP.SyRQjva14Zc-
                                                                                                                                                                                 
        my $tfile = Thundaural::Util::mymktempname($this->{storagedir}, $this->{cddevice}, 'discinfo');
	my $cmd = sprintf('%s --device %s -N -J -v toc,sectors > %s 2>&1', $this->{bin_cdda2wav}, $this->{cddevice}, $tfile);
	system($cmd);

        open(C2W, "<$tfile");
	my @output = <C2W>;
	close(C2W);
        #unlink($tfile);

	my(@x, $discidline, $x);
        my $tlens = [];

        $x = join('', @output);
        $x =~ s/,/\n/sg;
        @x = split(/\n+/, $x);
	if (@x) {
        	while(my $line = shift @x) {
                	if (my($min,$sec,$set) = $line =~ /^\s*\d+\.\(\s*(\d+):(\d+)\.(\d+)\)\s*$/) {
                        	push(@$tlens, ($min*60*75)+($sec*75)+$set);
                	}
		}
        }

	my ($cdindexid, $cddbid, $numtracks, $totaltime);
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

	die(sprintf("%s: failed to get all information\n", __PACKAGE__)) if (!$cdindexid || !$numtracks);

	return {cdindexid=>$cdindexid, cddbid=>$cddbid, numtracks=>$numtracks, tracklens=>$tlens, totaltime=>$totaltime};
}

sub get_xml {
	my $this = shift;
	my $cdindexid = shift;

	my $f = $this->{xmlfile};
	my $xml;
	if (defined($f) && $f && -s $f) {
		open(X, "<$f");
		$xml = join('', <X>);
		close(X);
	} else {
		# Create a user agent object
		my $ua = LWP::UserAgent->new;
		$ua->agent("unknown");
 
		# Create a request
		#<mm:cdindexid>BQlmXw_S1YAr0WAfVEZ8ar_pVhw-</mm:cdindexid>
		#<mm:cdindexid>_1dXKDRaKOA4KVYEr3HptYdKDAI-</mm:cdindexid>
		#<mm:cdindexid>zP9XT1MCijZ7lWP.SyRQjva14Zc-</mm:cdindexid>
		my $req = HTTP::Request->new(POST => 'http://mm.musicbrainz.org/cgi-bin/mq_2_1.pl');
		my $query = {
			tag_name=>'mq:GetCDInfo',
			content=>[
				{tag_name=>'mq:depth', content=>[1]},
				{tag_name=>'mm:cdindexid', content=>[$cdindexid]}
			]
		};
		my $wrapper = [{
			attrib=>{
				'xmlns:rdf'=>'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
				'xmlns:dc'=>'http://purl.org/dc/elements/1.1/',
				'xmlns:mq'=>'http://musicbrainz.org/mm/mq-1.1#',
				'xmlns:mm'=>'http://musicbrainz.org/mm/mm-2.1#'
			},
			tag_name=>'rdf:RDF',
			content=>[$query]
		}];

		my $c1 = XML::Ximple::ximple_to_string($wrapper);

		$req->content($c1);
 
		my $res = $ua->request($req);
 
		# Check the outcome of the response
		die(sprintf("%s: unable to interface with MusicBrainz\n", __PACKAGE__))
			unless ($res->is_success);
		$xml = $res->content;
	}
	if ($f && !-s $f) {
		open(X, ">$f");
		print X $xml;
		close(X);
	}
	$xml =~ s/\s+/ /g;
	return $xml;
}

sub extract_mb_gid {
	my $this = shift;
	my $url = shift;
	# 89ad4ac3-39f7-470e-963a-56509c546377 == various artists gid
	# MB apparently changed the format, the URL now has the version number in it as the first
	# component, which means that this re won't match because there are three components separated by
	# a slash, the version, the type, and the guid, whereas this re only matches two
	#my($type, $gid) = $url =~ m/^http:\/\/musicbrainz.org\/([^\/]+)\/([-0-9a-fA-F]+)(\.html)?$/;
	my @s = split(m@/@, $url);
	my $gid = pop @s;
	$gid =~ s/\.html$//g;
	my $type = pop @s; 
	return {type=>$type, gid=>$gid};
}

sub process_tree {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $parent = $o{'parent'};
	my $var = $o{'var'};

	$parent = $parent ? sprintf('%s_', $parent) : '';

	while (@$tree) {
		my $node = shift @$tree;
		next if (!ref($node));
		die("non-hash node found:\n".Dumper($node)."\n") if (ref($node) ne 'HASH');

		my $nodename = lc $node->{tag_name};
		my $vs = $var ? ', \'var\'=>$var' : '';
		my $c = sprintf('$this->handle_%s%s(\'attrib\'=>$node->{attrib}, \'tree\'=>$node->{content}%s);', $parent, $nodename, $vs);
		eval $c;
		if ($@) {
			my $re = sprintf("Can't locate object method \"handle_%s%s\" via package \"%s\"", $parent, $nodename, __PACKAGE__);
			warn $@ if ($@ !~ m/$re/);
		}
	}
}

sub handle_xml { return; }

sub handle_rdf {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	$this->process_tree('tree'=>$tree);
}

sub handle_result {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	$this->process_tree('tree'=>$tree, 'parent'=>'result');
}

sub handle_result_status {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	die "result: query failed" if ($tree->[0] ne 'OK');
}

sub handle_result_albumlist { return; }

sub handle_album {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $attrib = $o{'attrib'};
	my $y = $this->extract_mb_gid($attrib->{'about'});
	$this->{albuminfo}->{'gid'} = $y->{gid};
	my $a = {};
	$this->process_tree('tree'=>$tree, 'parent'=>'album', 'var'=>$a);
	$this->{albuminfo}->{'name'} = $a->{'name'};
	$this->{albuminfo}->{'other'} = $a;
}

sub handle_album_title {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $var = $o{'var'};
	$var->{name} = shift @$tree;
}

sub handle_album_creator {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
        my $y = $this->extract_mb_gid($o{'attrib'}->{'resource'});
        die("album resource attribute isn't artist") unless ($y->{type} eq 'artist');
        $this->{albuminfo}->{creator} = $y->{gid};
	$this->process_tree('tree'=>$tree);
}

sub handle_artist {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $attrib = $o{'attrib'};
	my $y = $this->extract_mb_gid($attrib->{'about'});
	die("artist about attribute isn't artist") unless ($y->{type} eq 'artist');
	my $tinfo = {'gid'=>$y->{gid}, name=>undef};
	$this->process_tree('tree'=>$tree, 'parent'=>'artist', 'var'=>$tinfo);
	$this->{artists}->{$tinfo->{gid}} = $tinfo;
        if ( defined($this->{albuminfo}->{creator}) &&
             $this->{albuminfo}->{creator} eq $tinfo->{gid}) {
                # gotta watch it here -- MusicBrainz should have artist resources later 
                # in the XML than the entities that reference those resources
                # I don't know if that is guaranteed
                $this->{albuminfo}->{artist} = $tinfo;
        }
}

sub handle_artist_title {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $var = $o{'var'};
	$var->{'name'} = shift @$tree;
}

sub handle_artist_sortname {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $var = $o{'var'};
	$var->{'sortname'} = shift @$tree;
}

sub handle_track {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $attrib = $o{'attrib'};
	my $y = $this->extract_mb_gid($attrib->{about});
	die("track about attribute isn't track\n") unless ($y->{type} eq 'track');
	my $tinfo = {};
	$tinfo->{gid} = $y->{gid};
	$this->process_tree('tree'=>$tree, 'parent'=>'track', 'var'=>$tinfo);
	push(@{$this->{albuminfo}->{tracks}}, $tinfo);
}

sub handle_track_creator {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $attrib = $o{'attrib'};
	my $var = $o{'var'};
	my $y = $this->extract_mb_gid($attrib->{resource});
	die("track_creator resource attribute isn't artist\n") unless ($y->{type} eq 'artist');
	$var->{creator} = $y->{gid};
}

sub handle_track_title {
	my $this = shift;
	my %o = @_;
	my $tree = $o{'tree'};
	my $var = $o{'var'};
	my $attrib = $o{'attrib'};
	$var->{name} = shift @$tree;
}

sub handle_artist_albumlist { return; }
sub handle_album_releasetype { return; }
sub handle_track_duration { return; }
sub handle_track_trmidlist { return; }
sub handle_album_tracklist { return; }
sub handle_album_releasestatus { return; }
sub handle_album_cdindexidlist { return; }
sub handle_album_asin { return; }
sub handle_album_coverart { return; }


1;

#    Thundaural Jukebox
#    Copyright (C) 2003-2005  Andrew A. Bakun
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
