#!/usr/bin/perl

package Themes::Original::VolumeLabel;

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
    $this->update_every(1);

    $this->{server} = $main::client;

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>140, -g=>140);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->surface($s);

    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>17, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->redraw();
    $this->{lastupdate} = 0;
    $this->{lastlines} = '';
    $this->{lasttrackref} = 0;

}

sub draw_info {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};

    my @lines = qw(v o l u m e);

    $this->erase();
    my $area = $this->area();
    my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $s->fill(0, $this->{bgcolor});
    $this->{font}->print_lines_justified(just=>0, surf=>$s, x=>20, y=>0, lines=>\@lines);
    $this->surface($s);

    $this->update_every(0);

    return 1;
}

1;

