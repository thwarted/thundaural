#!/usr/bin/perl

package Themes::Original::AlbumCover;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Widget::Button;
use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>110, -g=>110, -b=>110);
    $this->{fgcolor} = new SDL::Color(-r=>255, -g=>255, -b=>255);
    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{blank} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>24);;
    $this->{blank}->display_format();
}

sub set_album {
    my $this = shift;
    my %o = @_;
    my $album = $o{album};

    $this->{album} = $album;

    my $albumid = $album->albumid();

    my $coverart = $this->{album}->coverartfile();
    if (-s $coverart) {
        $this->set_frame(frame=>0, file=>$coverart, resize=>1);
    } else {
        $this->{blank}->fill(0, $this->{bgcolor});

        my @text = $this->{font}->wrap(rect=>$this->{blank}, lines=>[$album->performer(), ' ', $album->name()]);
        my $textheight = $this->{font}->height() * (scalar @text);
        my $surfheight = $this->{blank}->height();
        my $y = ($surfheight - $textheight) / 2;
        $this->{font}->print_lines_justified(just=>0, surf=>$this->{blank}, x=>int($this->{blank}->width() / 2), y=>$y, lines=>\@text);

        $this->set_frame(frame=>0, surface=>$this->{blank}, resize=>1);
    }
    $this->make_depressed_frame();

    $this->redraw();
}

1;

