#!/usr/bin/perl

package Themes::Original::RipperPage;

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
use Themes::Original::RipperInfo;
#use Themes::Original::RipAction;

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    $this->{server} = $main::client;

    my $acarea = new SDL::Rect(-x=>10, -y=>105, -height=>230, -width=>230);
    $this->add_widget(new Themes::Original::AlbumCover(name=>'AlbumCover', area=>$acarea));

    my $riarea = new SDL::Rect(-width=>1024-10-10-230-10, -height=>768-105-10, -x=>10+230+10, -y=>105);
    $this->add_widget(new Themes::Original::RipperInfo(name=>'rippinginfo', area=>$riarea));

    #my $rpbgcolor = new SDL::Color(-r=>140, -g=>140, -b=>140);
    #my $rpfgcolor = new SDL::Color(-r=>190, -g=>190, -b=>190);
    #my $black = new SDL::Color(-r=>0, -b=>0, -g=>0);
    #my $f = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>21, -bg=>$rpbgcolor, -fg=>$black);
    #my $rparea = new SDL::Rect(-height=>16, -width=>500, -x=>300, -y=>105);
    #my $rp = new Widget::ProgressBar(name=>'rippingprogress', area=>$rparea, bgcolor=>$rpbgcolor, fgcolor=>$rpfgcolor, font=>$f);
    #$rp->type('bar');
    #$rp->orientation('h');
    #$this->add_widget($rp);

    # add action widget here
}

1;

