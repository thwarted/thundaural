#!/usr/bin/perl

package Themes::Original::RipperInfo;

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
    $this->update_every(2100);

    $this->{server} = $main::client;

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>140, -g=>140);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    #my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    #$this->surface($s);

    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>17, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{lastupdate} = 0;
    $this->{lastlines} = '';
    $this->{lasttrackref} = 0;

}

sub draw_info {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};

    my @lines = ('hello', 'badfdsf', 'adfadfas', 'keriasfk dkfdkf dkf adkf');
    my $x = freeze(\@lines);
    if ($x ne $this->{lastlines}) {
        $this->erase();
        my $area = $this->area();
        my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
        $s->fill(0, $this->{bgcolor});
        $this->{font}->print_lines_justified(just=>-1, surf=>$s, x=>0, y=>0, lines=>\@lines);
        $this->surface($s);
        $this->{lastlines} = $x;
        return 1;
    }
    return 0;
}

1;

