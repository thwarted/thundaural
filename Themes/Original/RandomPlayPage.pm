#!/usr/bin/perl

package Themes::Original::RandomPlayPage;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Widget::Group;

use base 'Widget::Group';

use Themes::Original::RandomPlayButton;
use Themes::Original::RandomPlayInfo;

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    $this->{server} = $main::client;

    my $devices = $this->{server}->devices('play');

    my $buttonxpos = 10;
    foreach my $device (@$devices) {
        my $buttonypos = 110;
        foreach my $time (0, 5, 10, 20, 30, 45, 60, 90, 120) {
            my $area = new SDL::Rect(-width=>150, -height=>50, -x=>$buttonxpos, -y=>$buttonypos);
            $this->add_widget(new Themes::Original::RandomPlayButton(name=>"randomplay-$device-$time", device=>$device, duration=>$time, area=>$area));
            $buttonypos += 50 + 10;
        }
        $buttonxpos += 150 + 10;
    }

    my $area = new SDL::Rect(-width=>1024-20-$buttonxpos, -height=>120, -x=>$buttonxpos+10, -y=>110);
    $this->add_widget(new Themes::Original::RandomPlayInfo(name=>'randomplayinfo', area=>$area));
}

1;

