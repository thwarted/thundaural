#!/usr/bin/perl

package Themes::Original::AlbumPrev;

use strict;
use warnings;

use Thundaural::Logger qw(logger);

use Widget::Button;
use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;

    my $area = new SDL::Rect(-x=>52, -y=>668, -width=>95, -height=>95);
    $this->area($area);

    $this->set_frame(file=>'images/button-back-raised.gif', frame=>0);
    $this->set_depressed_frame(file=>'images/button-back-depressed.gif', frame=>0);

    $this->bgcolor(new SDL::Color(-r=>160, -g=>160, -b=>160));

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    my $c = $this->container();
    $c->adjust_album_offset(page=>-1);
}

1;

