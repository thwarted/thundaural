#!/usr/bin/perl

package Themes::Original::TrackScrollNext;

use strict;
use warnings;

use Thundaural::Logger qw(logger);

use Widget::Button;
use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;

    my $area = new SDL::Rect(-x=>945, -y=>768-75-10, -width=>66, -height=>75);
    $this->area($area);

    $this->set_frame(file=>'images/arrow-down-white.png', frame=>0);
    $this->set_depressed_frame(file=>'images/arrow-down-red.png', frame=>0);

    #$this->bgcolor(new SDL::Color(-r=>160, -g=>160, -b=>160));

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    logger("button ".$this->name()." was hit!");
    my $c = $this->container();
    $c->scroll_tracks(dir=>+9);

}

1;

