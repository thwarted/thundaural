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

my $track_display_mode = 2;

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>170, -b=>170, -g=>170);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    $this->{fontsmall} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>15, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{fontbig} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>34, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

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
    my @tracktext = ();
    my @numtext = ();
    my $toffset = $track->trackref();
    $toffset =~ s!^\d+/!!g;
    push(@tracktext, $track->name());
    my $trackperformer = $track->performer();
    push(@tracktext, $trackperformer) if ($trackperformer ne $albumperformer);
    my $vert = 0;
    if (scalar @tracktext < 2) {
        $vert = 14;
    }
    push(@numtext, "$toffset");
    if ($track_display_mode == 1) {
        $this->{font}->print_lines_justified(just=>0, surf=>$this->{face}, x=>int($this->{face}->width()/2), y=>$vert, lines=>\@tracktext);
        $this->{fontbig}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>2, y=>5, lines=>\@numtext);
        $this->{fontbig}->print_lines_justified(just=>1, surf=>$this->{face}, x=>$this->{face}->width()-2, y=>5, lines=>\@numtext);
    } else {
        my $namestart = 2 + $this->{fontbig}->width('88')+10;
        my $maxwidth = $this->{face}->width() - $namestart - 75;
        my $infotext = [ 
                $this->sectotime($track->length(), my $short = 1),
                $this->english_rank($track->rank()),
                ];
        $this->{fontsmall}->print_lines_justified(just=>1,  surf=>$this->{face}, x=>$this->{face}->width()-5, y=>7, lines=>$infotext);
        $this->{font}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>$namestart, y=>$vert, lines=>\@tracktext, 'truncate'=>1, maxwidth=>$maxwidth);
        $this->{fontbig}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>2, y=>5, lines=>\@numtext);
    }

    $this->set_frame(frame=>0, surface=>$this->{face}, resize=>0);

    $this->redraw();
}

sub onClick {
    my $this = shift;

    logger('track %s was selected', $this->{track}->trackref());
}

sub sectotime {
    my $this = shift;
    my $sec = shift || 0;
    my $short = shift || 0;

    my $min = int($sec / 60);
    $sec = $sec % 60;
    my $hrs = int($min / 60);
    $min = $min % 60;

    if ($short) {
        my @ret = ();
        push(@ret, $hrs) if ($hrs);
        push(@ret, sprintf("%02d", $min));
        push(@ret, sprintf("%02d", $sec));
        return join(":", @ret);
    } else {
        my @ret = ();
        push(@ret, "$hrs hours") if ($hrs);
        push(@ret, "$min minutes") if ($min);
        push(@ret, "$sec seconds") if ($sec);
        return join(' and ', @ret);
    }
}

sub english_rank {
    my $this = shift;
    my $rank = shift;
    
    return 'never played' if (!$rank);

    return 'first' if ($rank == 1);
    return 'second' if ($rank == 2);
    return 'third' if ($rank == 3);
    return 'fourth' if ($rank == 4);
    return 'fifth' if ($rank == 5);
    return 'sixth' if ($rank == 6);
    return 'seventh' if ($rank == 7);
    return 'eighth' if ($rank == 8);
    return 'ninth' if ($rank == 9);
    return 'tenth' if ($rank == 10);
    return 'eleventh' if ($rank == 11);
    return 'twelveth' if ($rank == 12);
    return 'thirteenth' if ($rank == 13);
    return 'fourteenth' if ($rank == 14);
    return $rank.'st' if ($rank =~ m/1$/);
    return $rank.'nd' if ($rank =~ m/2$/);
    return $rank.'rd' if ($rank =~ m/3$/);
    return $rank.'th';
}   

1;

