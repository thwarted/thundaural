#!/usr/bin/perl

package Themes::Original::StatsIcon;

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

    my $area = new SDL::Rect(-width=>90, -height=>90, -x=>820-90-10, -y=>2);
    $this->area($area);

    $this->add_frame(file=>'images/goto-stats.png', resize=>1);
    $this->add_depressed_frame(file=>'images/volume-max.png', resize=>1);
    #$this->add_frame(file=>'images/goto-albums.png', resize=>1);

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;

    $main::theme->show_page('StatsPage');
}

1;

