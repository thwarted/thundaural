#!/usr/bin/perl

package Themes::Original::NowPlayingPage;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Widget::Group;

use base 'Widget::Group';

use Themes::Original::AlbumCover;
use Themes::Original::NowPlayingInfo;
use Themes::Original::VolumeLabel;

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    $this->{server} = $main::client;

    my $acarea = new SDL::Rect(-x=>10, -y=>105, -height=>230, -width=>230);
    $this->add_widget(new Themes::Original::AlbumCover(name=>'AlbumCover', area=>$acarea));

    my $ifarea = new SDL::Rect(-width=>1024-10-10-230-10, -height=>768-105-10, -x=>10+230+10, -y=>105);
    $this->add_widget(new Themes::Original::NowPlayingInfo(name=>'nowplayinginfo', area=>$ifarea));

    my $dsarea = new SDL::Rect(-width=>40, -height=>360, -x=>10, -y=>370);
    my $bgcolor = new SDL::Color(-r=>140, -g=>140, -b=>140);
    my $fgcolor = new SDL::Color(-r=>180, -g=>180, -b=>180);
    my $labelcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
    my $f = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>21, -bg=>$fgcolor, -fg=>$labelcolor);
    my $w = new Widget::ProgressBar(name=>'volume', area=>$dsarea, bgcolor=>$bgcolor, fgcolor=>$fgcolor, font=>$f);
    $w->type('bar');
    $w->orientation('v');
    $this->add_widget($w);

    #my $vlarea = new SDL::Rect(-x=>55, -y=>370, -width=>40, -height=>360);
    #my $vl = new Themes::Original::VolumeLabel(name=>'volumelabel', area=>$vlarea);
    #$this->add_widget($vl);
}

1;

