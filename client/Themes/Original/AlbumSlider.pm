#!/usr/bin/perl

package Themes::Original::AlbumSlider;

use strict;
use warnings;

use Thundaural::Logger qw(logger);

use Widget::ProgressBar;
use base 'Widget::ProgressBar';

sub widget_initialize {
    my $this = shift;

    my $area = new SDL::Rect(-x=>52+95+20, -y=>768-32-40, -width=>877-20-(52+95+20), -height=>40);
    $this->area($area);

    $this->bgcolor(new SDL::Color(-r=>140, -g=>140, -b=>140));
    $this->fgcolor(new SDL::Color(-r=>0x4b, -g=>0x2e, -b=>0x82));
    $this->orientation('h');
    $this->font('./fonts/Vera.ttf');
    $this->type('line');
    $this->{minsize} = int($area->width() / 100);

    $this->SUPER::widget_initialize();
}

sub onClick {
    my $this = shift;
    my %o = @_;
    my $pct = $o{percentage};

    my $c = $this->container();
    $c->adjust_album_offset(percentage=>$pct);
}

sub line_thickness {
    my $this = shift;

    my $c = $this->container();
    my $psize = $c->page_size();
    my $total = $c->total_albums();
    my $x = $psize / $total * $this->area()->width();
    $x = $this->{minsize} if ($x < $this->{minsize});
    return $x;
}

1;

