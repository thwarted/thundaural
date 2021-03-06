#!/usr/bin/perl

package Thundaural::Client::Track;

use strict;
use warnings;

use Carp qw(cluck);
use Thundaural::Logger qw(logger);

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $proto = ref($class) || $class;
    my $this = {};
    my %o = @_;

    if (!$o{info}->{length} || $o{info}->{length} <= 2) {
        # this track is less than 2 seconds long, skip it
        # it sure is cool to fill up the track listing to hide 
        # your hidden track
        # when I grow up I want to be cool like bands that do this
        logger("track %s is empty", $o{info}->{trackref});
        return undef;
    }

    $this->{info} = $o{info};
    bless $this, $proto;
}

sub album {
    my $this = shift;

    if ($this->type() eq 'read') {
        return new Thundaural::Client::Album(info=>$this->{info});
    }
    # type = 'play'
    return new Thundaural::Client::Album(trackref=>$this->{info}->{trackref});
}

sub tohash {
    my $this = shift;
    return $this->{info};
}

sub play {
    my $this = shift;
    my $channel = shift;

    $main::client->play($this->trackref(), $channel);
}

sub AUTOLOAD {
    my $this = shift;

    my($g) = $AUTOLOAD =~ m/::(\w+)$/;
    if (exists($this->{info}->{$g})) {
        return $this->{info}->{$g};
    }
    return '';
}

1;

