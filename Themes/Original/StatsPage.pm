#!/usr/bin/perl

package Themes::Original::StatsPage;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Widget::Group;
use Widget::ProgressBar;

use base 'Widget::Group';

use Themes::Original::StatsInfo;

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    $this->{server} = $main::client;

    my $inarea = new SDL::Rect(-width=>1024-20, -height=>768-200-20-100-10, -x=>10, -y=>100+10);
    my $i = new Themes::Original::StatsInfo(name=>'statsinfo', area=>$inarea);
    $this->add_widget($i);

    my $dsarea = new SDL::Rect(-width=>1024-20, -height=>25, -x=>10, -y=>768-200);
    my $bgcolor = new SDL::Color(-r=>140, -g=>140, -b=>140);
    my $fgcolor = new SDL::Color(-r=>180, -g=>180, -b=>180);
    my $labelcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
    my $f = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>21, -bg=>$fgcolor, -fg=>$labelcolor);
    my $w = new Widget::ProgressBar(name=>'diskspace', area=>$dsarea, bgcolor=>$bgcolor, fgcolor=>$fgcolor, font=>$f);
    $w->type('bar');
    $this->add_widget($w);
}

1;

