#!/usr/bin/perl

package Themes::Original::TrackSelect;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::TTFont;

use Thundaural::Logger qw(logger);
use Widget::Button;

use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>170, -b=>170, -g=>170);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{fontbig} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>30, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{face} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);

    $this->{track} = $o{track};
}

sub start {
    my $this = shift;

    $this->set_track(track=>$this->{track});
}

sub set_position {
    my $this = shift;
    my($x, $y, $w, $h) = @_;
    $this->area(new SDL::Rect(-x=>$x, -y=>$y, -width=>$w, -height=>$h));
    $this->make_depressed_frame(); # because the background might have changed
    $this->redraw();
}

sub set_track {
    my $this = shift;
    my %o = @_;
    my $track = $o{track};
    my $album = $o{album};

    $this->{track} = $track;
    $this->{album} = $album;

    return if (!$track);

    my $albumperformer = '';
    if ($album) {
        $albumperformer = $album->performer();
    }

    $this->{face}->fill(0, $this->{bgcolor});
    my @text1 = ();
    my @text2 = ();
    my $toffset = $track->trackref();
    $toffset =~ s!^\d+/!!g;
    push(@text1, $track->name());
    my $trackperformer = $track->performer();
    push(@text1, $trackperformer) if ($trackperformer ne $albumperformer);
    my $vert = 0;
    if (scalar @text1 < 2) {
        $vert = 10;
    }
    push(@text2, "$toffset");
    $this->{font}->print_lines_justified(just=>0, surf=>$this->{face}, x=>int($this->{face}->width()/2), y=>$vert, lines=>\@text1);
    $this->{fontbig}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>2, y=>5, lines=>\@text2);
    $this->{fontbig}->print_lines_justified(just=>1, surf=>$this->{face}, x=>$this->{face}->width()-2, y=>5, lines=>\@text2);

    $this->set_frame(frame=>0, surface=>$this->{face}, resize=>0);

    $this->redraw();
}

sub onClick {
    my $this = shift;

    logger('track %s was selected', $this->{track}->trackref());
}

1;

