#!/usr/bin/perl

package Themes::Original::RandomPlayButton;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::TTFont;

use Thundaural::Logger qw(logger);
use Widget::Button;

use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>140, -b=>140, -g=>140);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    $this->{face} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->{face}->fill(0, $this->{bgcolor});

    my $font = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{duration} = $o{duration};
    $this->{device} = $o{device};

    my $m = ($this->{duration} ? $this->{duration}." minutes" : "off");
    my $fh = $font->height();
    my $fw = $font->width($m);
    my @lines = ($m);
    push(@lines, $this->{device}."") if ($this->{device} ne 'main');
    my $y = ($area->height() - ((scalar @lines) * $fh)) / 2;
    $font->print_lines_justified(just=>0, surf=>$this->{face}, x=>($area->width()/2), y=>$y, lines=>\@lines);

    $this->set_frame(frame=>0, surface=>$this->{face}, resize=>0);
    $this->make_depressed_frame();
    $this->redraw();
}

sub onClick {
    my $this = shift;

    logger('random play %d on %s', $this->{duration}, $this->{device});
    $main::client->random_play(duration=>$this->{duration}, device=>$this->{device});
    # force the info surface to get new updates as soon as possible
    $this->container()->get_widget('randomplayinfo')->update_every(150);
}

1;

