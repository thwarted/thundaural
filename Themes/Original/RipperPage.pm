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
use Themes::Original::RipActionButton;

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    $this->{server} = $main::client;

    my $acarea = new SDL::Rect(-x=>10, -y=>105, -height=>300, -width=>300);
    $this->add_widget(new Themes::Original::AlbumCover(name=>'AlbumCover', area=>$acarea));

    my $riarea = new SDL::Rect(-width=>1024-10-10-300-10, -height=>768-105-10, -x=>10+300+10, -y=>126);
    $this->add_widget(new Themes::Original::RipperInfo(name=>'rippinginfo', area=>$riarea));

    my $raarea = new SDL::Rect(-width=>150, -height=>50, -x=>50, -y=>300+105+100);
    $this->add_widget(new Themes::Original::RipActionButton(name=>'ripaction', area=>$raarea));

    my $bgcolor = new SDL::Color(-r=>140, -g=>140, -b=>140);
    my $halfbg = new SDL::Color(-r=>160, -g=>160, -b=>160);
    my $fgcolor = new SDL::Color(-r=>180, -g=>180, -b=>180);
    my $labelcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
    my $f = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>14, -bg=>$halfbg, -fg=>$labelcolor);

    my $rparea = new SDL::Rect(-width=>600, -height=>16, -x=>10+300+10, -y=>105);
    my $rp = new Widget::ProgressBar(name=>'ripprogress', area=>$rparea, bgcolor=>$bgcolor, fgcolor=>$fgcolor, font=>$f);
    $rp->type('bar');
    $rp->orientation('h');
    $this->add_widget($rp);

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

