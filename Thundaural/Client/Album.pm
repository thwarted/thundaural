#!/usr/bin/perl

# $Header$

package Thundaural::Client::Album;

use strict;
use warnings;

use Thundaural::Client::Track;

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

    $this->{albumid} = $o{albumid};
    $this->{server} = $main::client;
    $this->{info} = $o{info};
    $this->{tracks} = [];
    $this->{tmpdir} = $main::tmpdir;

    if (!$this->{info}) {
        my $x = $this->{server}->getlist('album', $this->{albumid});
        if (ref($x) eq 'ARRAY' && scalar @{$x}) {
            $this->{info} = shift @{$x};
        } else {
            $this->{info} = {};
        }
    }

    bless $this, $proto;
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

    return sprintf('%s/thundaural-coverartcache-album%06d.jpg', $this->{tmpdir}, $this->{albumid});
}


1;


