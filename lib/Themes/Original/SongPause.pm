#!/usr/bin/perl

package Themes::Original::SongPause;

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

    my $area = new SDL::Rect(-width=>72, -height=>72, -x=>80, -y=>450);
    $this->area($area);

    $this->add_frame(file=>'media/images/button-pause-raised.png', resize=>0);
    $this->add_depressed_frame(file=>'media/images/button-pause-depressed.png', resize=>0);

    $this->add_frame(file=>'media/images/button-play-raised.png', resize=>0);
    $this->add_depressed_frame(file=>'media/images/button-play-depressed.png', resize=>0);

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    my $dev = $main::client->devices('play');
    my $pauseon = shift @$dev;
    logger('requesting pause of %s', $pauseon);
    $main::client->pause($pauseon);

    my $nf = $this->frame();
    $this->frame($nf ? 0 : 1);
}

1;

