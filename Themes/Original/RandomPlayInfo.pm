#!/usr/bin/perl

package Themes::Original::RandomPlayInfo;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::TTFont;
use Storable qw(freeze);

use Thundaural::Logger qw(logger);
use Widget::Surface;

use base 'Widget::Surface';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();
    $this->update_every(50); # force it to update as soon as possible

    $this->{bgcolor} = new SDL::Color(-r=>140, -b=>140, -g=>140);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->surface($s);

    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{lastupdate} = 0;
    $this->{lastlines} = '';

}

sub update {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};

    $this->update_every(10000) if (!$this->{started}); # okay, we're going to update right after starting up, so reset this to a sane value
    $this->{started} = 1;
    my @outputs = @{$main::client->devices('play')};
    my @lines = ();
    foreach my $device (@outputs) {
        my $s = $main::client->will_random_play_until($device);
        my $m;
        if ($s) {
            $m = "$device will random play until ".localtime($s);
        } else {
            $m = "random play is off on $device";
        }
        push(@lines, $m, " ");
    }
    my $x = freeze(\@lines);
    if ($x ne $this->{lastlines}) {
        # finally detected the change, so don't query so often now
        $this->update_every(10000);
        my $area = $this->area();
        my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
        $this->{font}->print_lines_justified(just=>0, surf=>$s, x=>$this->area()->width()/2, y=>10, lines=>\@lines);
        $this->surface($s);
        $this->{lastlines} = $x;
        return 1;
    }
    return 0;
}

1;

