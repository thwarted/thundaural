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
use Themes::Original::VolumeSelect;
use Themes::Original::SongPause;
use Themes::Original::SongSkip;

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    $this->{server} = $main::client;

    my $bgcolor = new SDL::Color(-r=>140, -g=>140, -b=>140);
    my $halfbg = new SDL::Color(-r=>160, -g=>160, -b=>160);
    my $fgcolor = new SDL::Color(-r=>180, -g=>180, -b=>180);
    my $labelcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
    my $f = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>14, -bg=>$halfbg, -fg=>$labelcolor);

    my $acarea = new SDL::Rect(-x=>10, -y=>105, -height=>300, -width=>300);
    $this->add_widget(new Themes::Original::AlbumCover(name=>'AlbumCover', area=>$acarea));

    my $ifarea = new SDL::Rect(-width=>1024-10-10-300-10, -height=>768-105-15, -x=>10+300+10, -y=>126); # 105 + 16
    $this->add_widget(new Themes::Original::NowPlayingInfo(name=>'nowplayinginfo', area=>$ifarea));

    my $sparea = new SDL::Rect(-width=>600, -height=>16, -x=>10+300+10, -y=>105);
    my $sp = new Widget::ProgressBar(name=>'songprogress', area=>$sparea, bgcolor=>$bgcolor, fgcolor=>$fgcolor, font=>$f);
    $sp->type('bar');
    $sp->orientation('h');
    $this->add_widget($sp);

    my $vsarea = new SDL::Rect(-width=>40, -height=>290, -x=>10, -y=>440);
    my $vs = new Widget::ProgressBar(name=>'volumeselect', area=>$vsarea, bgcolor=>$bgcolor, fgcolor=>$fgcolor);
    $vs->set_onClick( sub { my $this = shift; my %o = @_; $this->percent_full($o{percentage}); } );
    $vs->type('bar');
    $vs->orientation('v');
    $this->add_widget($vs);

    $this->add_widget(new Themes::Original::SongPause(name=>'songpause'));
    $this->add_widget(new Themes::Original::SongSkip(name=>'songskip'));

    #my $clockarea = new SDL::Rect(-x=>80, -y=>730-20, -height=>20, -width=>150);
    #my $clock = new Themes::Original::Clock(name=>'clock', area=>$clockarea);
    #$this->add_widget($clock);

    my %vicons = (loud=>348+70, quiet=>730);
    foreach my $iconlabel (keys %vicons) {
        my $r = new SDL::Rect(-width=>22, -height=>21, -x=>20, -y=>$vicons{$iconlabel});
        my $i = new Widget::Button(name=>"volume-icon-$iconlabel", area=>$r);
        $i->add_frame(file=>"images/volume-speaker-$iconlabel.png", resize=>0);
        $this->add_widget($i);
    }
}

1;

