#!/usr/bin/perl

# $Header$

package Thundaural::Client::Album;

use strict;
use warnings;

use Thundaural::Client::Track;

my $blankpng = pack('V*', 20617, 18254, 2573, 2586, 0, 3328, 18505, 21060,
0, 256, 0, 256, 520, 0, 36864, 21367,
222, 0, 28681, 22856, 115, 2816, 19, 2816,
275, 39424, 6300, 0, 1792, 18804, 17741, 54279,
2570, 6408, 51492, 4198, 45, 0, 18703, 16708,
30804, 257, 4, 65531, 65280, 65535, 65029, 65026,
26185, 11118, 0, 0, 17737, 17486, 17070, 33376,);

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $proto = ref($class) || $class;
    my $this = {};
    my %o = @_;

    if ($o{trackref}) {
        my($a, $x) = split(/\//, $o{trackref});
        $o{albumid} = $a;
    }

    $this->{tmpdir} = $main::tmpdir;
    $this->{albumid} = $o{albumid};
    $this->{server} = $main::client;
    $this->{info} = $o{info};
    $this->{tracks} = [];

    if (!$this->{info}) {
        $this->{info} = $this->{server}->album_hash(albumid=>$this->{albumid});
    }
    if (!$this->{albumid}) {
        if ($this->{info}->{type} eq 'read') {
            $this->{albumid} = 'ripping';
        }
    }

    bless $this, $proto;
}

sub hash {
    my $this = shift;
    return {%{$this->{info}}}; # dupe it
}

sub albumid {
    my $this = shift;
    return $this->{albumid};
}

sub AUTOLOAD {
    my $this = shift;

    my($g) = $AUTOLOAD =~ m/::(\w+)$/;
    if (exists($this->{info}->{$g})) {
        return $this->{info}->{$g};
    }
    return '';
}

sub tracklist {
    my $this = shift;

    if ($this->{albumid} eq 'ripping') {
        return [];
    }
    if (! (scalar @{$this->{tracks}}) ) {
        my $x = $this->{server}->getlist('tracks', $this->{albumid});
        my @n = ();
        foreach my $t (@{$x}) {
            my $trk = new Thundaural::Client::Track(info=>$t);
            push(@n, $trk) if ($trk);
        }
        $this->{tracks} = \@n;
    }
    return $this->{tracks};
}

sub coverartfile($) {
    my $this = shift;
    my $albumid = $this->{albumid};

    my $tmpfile = $this->_coverart_localfile($albumid);
    if (! -s $tmpfile) {
        my $x = $this->{server}->coverart(albumid=>$albumid, outputfile=>$tmpfile);
        if (defined($x) && ($tmpfile eq $x)) {
            $this->{coverartfile} = $x;
            return $x;
        }
    }
    return $tmpfile;
}

sub _coverart_localfile {
    my $this = shift;

    if ($this->{albumid} eq 'ripping') {
        return sprintf('%s/thundaural-coverartcache-album-%s-%d.jpg', $this->{tmpdir}, $this->{albumid}, ($this->started() || -1));
    }
    return sprintf('%s/thundaural-coverartcache-album%06d.jpg', $this->{tmpdir}, $this->{albumid});
}


1;


