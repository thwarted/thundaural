#!/usr/bin/perl

package Themes::Original::AlbumGoto;

use strict;
use warnings;

use Thundaural::Logger qw(logger);

use Widget::ProgressBar;
use base 'Widget::ProgressBar';
use Data::Dumper;

my $labelfont;
my @labels;

sub widget_initialize {
    my $this = shift;

    my $area = new SDL::Rect(-x=>52+95+20, -y=>768-32-10, -width=>877-20-(52+95+20), -height=>40);
    $this->area($area);

    my $bg = new SDL::Color(-r=>140, -g=>140, -b=>140);
    $this->bgcolor($bg);
    my $fg = new SDL::Color(-r=>0xd0, -g=>0xd0, -b=>0xd0);
    my $text = new SDL::Color(-r=>0, -g=>0, -b=>0);
    $this->fgcolor($fg);

    $labelfont = new SDL::TTFont(-name=>'media/fonts/Vera.ttf', -size=>25, -bg=>$bg, -fg=>$text);
    @labels = $main::client->album_prefixes();

    $this->orientation('h');
    $this->type('line');
    $this->label(\&draw_label); # will be called on $this
    $this->{labelheight} = $labelfont->height('0');
    $this->{labeltop} = int(($area->height() - $this->{labelheight}) / 2);
    $this->{maxsize} = $labelfont->width('m'); # widest character?
    $this->{minsize} = $area->width() / (scalar @labels);

    $this->SUPER::widget_initialize();
}

sub line_thickness {
    my $this = shift;

    return int($this->area()->width() / (scalar @labels));
}

sub draw_label {
    my $this = shift;
    my $surface = shift;

    my $start = 0;
    logger("drawing label");
    foreach my $l (@labels) {
        my $s = $start;
        my $charoffset = ($this->{minsize} - $labelfont->width("$l")) / 2;
        $labelfont->print($surface, $s + $charoffset, $this->{labeltop}, "$l");
        $start += $this->{minsize};
    }
}

sub onClick {
    my $this = shift;
    my %o = @_;
    my $pct = $o{percentage};

    my $c = $this->container();
    my $letter = $main::client->album_prefix_from_percentage(percentage=>$pct);
    $c->adjust_album_offset(letter=>$letter);
}

1;

#    Thundaural Jukebox
#    Copyright (C) 2003-2005  Andrew A. Bakun
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
