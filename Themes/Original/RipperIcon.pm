#!/usr/bin/perl

package Themes::Original::RipperIcon;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::Event;

use Thundaural::Logger qw(logger);

use Widget::Button;
use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;

    $this->bgcolor(new SDL::Color(-r=>160, -g=>160, -b=>160));

    my $area = new SDL::Rect(-width=>90, -height=>90, -x=>820, -y=>2);
    $this->area($area);

    $this->add_frame(file=>'images/ripcdrom-idle.png', resize=>1);
    $this->add_frame(file=>'images/ripcdrom-busy.png', resize=>1);
    $this->add_depressed_frame(file=>'images/ripcdrom-busy.png', resize=>1);
    $this->add_depressed_frame(file=>'images/ripcdrom-busy.png', resize=>1);

    #$this->animate(1000);

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    logger($this->name()." was hit");
    my $n = $this->theme()->get_widget('IconNowPlaying');
    if ($this->animate()) {
        $this->animate(0);
        $n->animate(0);
    } else {
        $this->animate(800);
        $n->animate(700);
    }
}

1;

