#!/usr/bin/perl

package Themes::Original::SongSkip;

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

    my $area = new SDL::Rect(-width=>72, -height=>72, -x=>80, -y=>450+100);
    $this->area($area);

    $this->set_frame(file=>'media/images/button-skip-raised.png', resize=>0);
    $this->set_depressed_frame(file=>'media/images/button-skip-depressed.png', resize=>0);

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    logger($this->name()." was hit");
}

1;

