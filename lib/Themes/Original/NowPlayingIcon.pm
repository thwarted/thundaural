#!/usr/bin/perl

package Themes::Original::NowPlayingIcon;

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

    my $area = new SDL::Rect(-width=>90, -height=>90, -x=>5, -y=>2);
    $this->area($area);

    $this->set_frame(file=>'media/images/nowplaying-speaker0.png', resize=>1, frame=>0);
    $this->set_frame(file=>'media/images/nowplaying-speaker1.png', resize=>1, frame=>1);
    $this->set_frame(file=>'media/images/nowplaying-speaker2.png', resize=>1, frame=>2);
    $this->set_frame(file=>'media/images/nowplaying-speaker3.png', resize=>1, frame=>3);
    $this->set_frame(file=>'media/images/nowplaying-speaker4.png', resize=>1, frame=>4);
    $this->set_frame(file=>'media/images/nowplaying-speaker5.png', resize=>1, frame=>5);
    $this->set_frame(file=>'media/images/nowplaying-speaker6.png', resize=>1, frame=>6);

    $this->set_depressed_frame(file=>'media/images/nowplaying-speaker0.png', resize=>1, frame=>0);
    $this->set_depressed_frame(file=>'media/images/nowplaying-speaker1.png', resize=>1, frame=>1);
    $this->set_depressed_frame(file=>'media/images/nowplaying-speaker2.png', resize=>1, frame=>2);
    $this->set_depressed_frame(file=>'media/images/nowplaying-speaker3.png', resize=>1, frame=>3);
    $this->set_depressed_frame(file=>'media/images/nowplaying-speaker4.png', resize=>1, frame=>4);
    $this->set_depressed_frame(file=>'media/images/nowplaying-speaker5.png', resize=>1, frame=>5);
    $this->set_depressed_frame(file=>'media/images/nowplaying-speaker6.png', resize=>1, frame=>6);

    #$this->animate(550);

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    $main::theme->show_page('NowPlayingPage');
}

1;

