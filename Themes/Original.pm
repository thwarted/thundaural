#!/usr/bin/perl

package Themes::Original;

use strict;
use warnings;

use Data::Dumper;

use Thundaural::Logger qw(logger);
use Themes::Base;

use base 'Themes::Base';

use Themes::Original::NowPlayingIcon;
use Themes::Original::AlbumsIcon;
use Themes::Original::RandomPlayIcon;
use Themes::Original::StatsIcon;
use Themes::Original::RipperIcon;
use Themes::Original::Clock;

use Themes::Original::NowPlayingPage;
use Themes::Original::AlbumsPage;
use Themes::Original::TrackListing;
use Themes::Original::RandomPlayPage;
use Themes::Original::StatsPage;
use Themes::Original::RipperPage;

sub theme_initialize {
    my $this = shift;

    #$this->bgimage(new SDL::Surface(-name=>'images/1024x768-Appropriately-Left-Handed-1.png'));
    #$this->bgimage(new SDL::Surface(-name=>'images/bgmetal2.png'));
    $this->bgcolor(new SDL::Color(-r=>160, -g=>160, -b=>160));

    $this->add_widget(new Themes::Original::AlbumsIcon(name=>'IconAlbums'));
    $this->add_widget(new Themes::Original::RandomPlayIcon(name=>'IconRandomPlay'));
    $this->add_widget(new Themes::Original::StatsIcon(name=>'IconStats'));
    $this->add_widget(new Themes::Original::RipperIcon(name=>'IconRipper'));
    $this->add_widget(new Themes::Original::NowPlayingIcon(name=>'IconNowPlaying'));

    my $clockarea = new SDL::Rect(-x=>440, -y=>20, -height=>60, -width=>250);
    my $clock = new Themes::Original::Clock(name=>'clock', area=>$clockarea);
    $this->add_widget($clock);

    $this->add_widget(new Themes::Original::NowPlayingPage(name=>'NowPlayingPage'));
    $this->add_widget(new Themes::Original::AlbumsPage(name=>'AlbumsPage'));
    $this->add_widget(new Themes::Original::TrackListing(name=>'TrackListing'));
    $this->add_widget(new Themes::Original::RandomPlayPage(name=>'RandomPlayPage'));
    $this->add_widget(new Themes::Original::StatsPage(name=>'StatsPage'));
    $this->add_widget(new Themes::Original::RipperPage(name=>'RipperPage'));

}

sub start {
    my $this = shift;

    $this->SUPER::start();
    $this->show_page('NowPlayingPage');
}

sub show_page {
    my $this = shift;
    my $showpage = shift;

    # hide all pages
    my @pages = qw(AlbumsPage TrackListing RandomPlayPage NowPlayingPage StatsPage RipperPage);
    foreach my $p (@pages) {
        next if ($p eq $showpage);
        my $w = $this->get_widget($p);
        if ($w->visible()) {
            $w->visible(0);
        }
    }

    # show only one
    my $w = $this->get_widget($showpage);
    if ($w) {
        $w->visible(1);
    } else {
        logger("unable to find page widget $showpage");
    }
}


1;
