#!/usr/bin/perl

package Themes::Original::AlbumSelect;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Widget::Button;
use base 'Widget::Button';

#$SIG{'__DIE__'} = sub { use Carp; confess(@_); };


sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>110, -g=>110, -b=>110);
    $this->{fgcolor} = new SDL::Color(-r=>255, -g=>255, -b=>255);
    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{blank} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>24);;
    $this->{blank}->display_format();

    $this->{album} = $o{album};
    #$this->set_album($o{album});
}

sub start {
    my $this = shift;

    #logger("starting %s", $this->name());
    $this->set_album(album=>$this->{album}, force=>1);
}

sub set_album {
    my $this = shift;
    my %o = @_;
    my $album = $o{album};
    my $force = $o{force};

    my $newalbumid = $album ? $album->albumid() : 0;
    my $oldalbumid = $this->{album} ? $this->{album}->albumid() : 0;
    #logger('%s: newalbumid = %d, old = %d', $this->name(), $newalbumid, $this->{album}->albumid());
    if ($force || $oldalbumid != $newalbumid) {
        $this->{album} = $album;
        if ($newalbumid) {
            my $coverart = $this->{album}->coverartfile();
            if (-s $coverart) {
                $this->set_frame(frame=>0, file=>$coverart, resize=>1);
                $this->make_depressed_frame();
            } else {
                $this->{blank}->fill(0, $this->{bgcolor});

                my @text = ($album->performer(), ' ', $album->name(), sprintf('%d tracks', scalar @{$album->tracklist()}));
                @text = $this->{font}->wrap(rect=>$this->{blank}, lines=>\@text);

                my $textheight = $this->{font}->height() * (scalar @text);
                my $surfheight = $this->{blank}->height();
                my $y = ($surfheight - $textheight) / 2;
                $this->{font}->print_lines_justified(just=>0, surf=>$this->{blank}, x=>int($this->{blank}->width() / 2), y=>$y, lines=>\@text);
                $this->set_frame(frame=>0, surface=>$this->{blank}, resize=>1);
                $this->make_depressed_frame();
            }
            $this->redraw();
        } else {
            $this->visible(0);
        }
    }
}

sub onClick {
    my $this = shift;

    my $t = $this->theme();
    my $tl = $t->get_widget('TrackListing');

    if ($tl) {
        $tl->show_album_tracks(album=>$this->{album});
        $main::theme->show_page('TrackListing');
    } else {
        logger("unable to find TrackListing widget");
    }
}

1;

