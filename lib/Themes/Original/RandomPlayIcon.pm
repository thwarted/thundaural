#!/usr/bin/perl

package Themes::Original::RandomPlayIcon;

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

    my $area = new SDL::Rect(-width=>90, -height=>90, -x=>300, -y=>2);
    $this->area($area);

    $this->set_frame(file=>'images/randomize.png', resize=>1, frame=>0);
    #$this->set_depressed_frame(file=>'images/button-back-raised.gif', resize=>1, frame=>0);

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    logger($this->name()." was hit");
    $main::theme->show_page('RandomPlayPage');
}

1;

