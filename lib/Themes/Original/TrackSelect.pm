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
use Themes::Common qw(sectotime english_rank);

use base 'Widget::Button';

my $track_display_mode = 2;

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>170, -b=>170, -g=>170);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    $this->{fontsmall} = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>15, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{font} = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{fontbig} = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>34, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{namestart} = 2 + $this->{fontbig}->width('88')+10;
    $this->{infowidth} = $this->{font}->width('never played');

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
    my $tn = $track->name();
    $tn =~ s/`/'/g;
    push(@tracktext, $tn);
    my $trackperformer = $track->performer();
    push(@tracktext, $trackperformer) if ($trackperformer ne $albumperformer);
    my $vert = 0;
    if (scalar @tracktext < 2) {
        $vert = 14;
    }
    push(@numtext, "$toffset");
    if ($track_display_mode == 3) {
        my $namestart = $this->{namestart};
        my $maxwidth = $this->{face}->width() - $namestart - 75;
        my $infotext = [ 
                sectotime($track->length(), short=>1),
                english_rank($track->rank()),
                ];
        $this->{fontsmall}->print_lines_justified(just=>1,  surf=>$this->{face}, x=>$this->{face}->width()-5, y=>7, lines=>$infotext);
        $this->{font}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>$namestart, y=>$vert, lines=>\@tracktext, 'truncate'=>1, maxwidth=>$maxwidth);
        $this->{fontbig}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>2, y=>5, lines=>\@numtext);
    } elsif ($track_display_mode == 2) {
        my $namestart = $this->{namestart};
        my $maxwidth = $this->{face}->width() - $namestart - $this->{infowidth};
        if (scalar @tracktext == 1) {
            if ($this->{font}->width($tracktext[0]) > $maxwidth) {
                @tracktext = $this->{font}->wrap(rect=>new SDL::Rect(-width=>$maxwidth, -height=>$this->area->height()), lines=>\@tracktext, donttruncate=>1);
                $vert = 0;
            }
        }
        my $infotext = [ 
                sectotime($track->length(), short=>1),
                english_rank($track->rank()),
                ];
        $this->{fontsmall}->print_lines_justified(just=>1,  surf=>$this->{face}, x=>$this->{face}->width()-5, y=>7, lines=>$infotext);
        $this->{font}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>$namestart, y=>$vert, lines=>\@tracktext, 'truncate'=>1, maxwidth=>$maxwidth);
        $this->{fontbig}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>2, y=>5, lines=>\@numtext);
    } else {
        # alternative, old track display mode that isn't as smart
        $this->{font}->print_lines_justified(just=>0, surf=>$this->{face}, x=>int($this->{face}->width()/2), y=>$vert, lines=>\@tracktext);
        $this->{fontbig}->print_lines_justified(just=>-1, surf=>$this->{face}, x=>2, y=>5, lines=>\@numtext);
        $this->{fontbig}->print_lines_justified(just=>1, surf=>$this->{face}, x=>$this->{face}->width()-2, y=>5, lines=>\@numtext);
    }

    $this->set_frame(frame=>0, surface=>$this->{face}, resize=>0);

    $this->redraw();
}

sub onClick {
    my $this = shift;

    my $dev = $main::client->devices('play');
    my $playon = shift @$dev;
    logger('requesting track %s on %s', $this->{track}->trackref(), $playon);
    $this->{track}->play($playon);
    $main::theme->show_page('NowPlayingPage');
}

1;

