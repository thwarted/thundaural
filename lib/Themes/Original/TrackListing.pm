#!/usr/bin/perl

package Themes::Original::TrackListing;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Surface;

use Thundaural::Logger qw(logger);
use Widget::Group;

use Themes::Original::TrackSelect;
use Themes::Original::AlbumCover;
use Themes::Original::TrackScrollPrev;
use Themes::Original::TrackScrollNext;
use Themes::Original::PlayAllButton;

use base 'Widget::Group';

use constant {
    MAXTRACKS => 40
};

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    my $positions = [];
    foreach my $y (0..MAXTRACKS) { # we'll only support up to 40 tracks on a single album
        #push(@$positions, [250, 105 + $y * 55, 690, 50]);
        push(@$positions, [250, 160+($y * 55), 690, 50]);
    }
    $this->{positions} = $positions;
    $this->{onscreen} = 10;

    my $c = 0;
    $this->{trackbuttons} = [];
    foreach my $pos (@{$positions}) {
        my($x, $y, $w, $h) = @{$pos};
        my $p = new SDL::Rect(-x=>$x, -y=>$y, -width=>$w, -height=>$h);
        my $name = "trackselect$c";
        logger('creating %s at %s', $name, $p->tostr());
        my $wx = new Themes::Original::TrackSelect(name=>$name, area=>$p);
        $this->add_widget($wx);
        push(@{$this->{trackbuttons}}, $name);
        $c++;
    }
    $this->{offset} = 0;

    my $acarea = new SDL::Rect(-x=>10, -y=>105, -height=>230, -width=>230);
    my $ac = new Themes::Original::AlbumCover(name=>'AlbumCover', area=>$acarea);
    $ac->set_onClick( sub { $main::theme->show_page('AlbumsPage'); } );
    $this->add_widget($ac);
    $this->add_widget(new Themes::Original::TrackScrollNext(name=>'TrackScrollNext'));
    $this->add_widget(new Themes::Original::TrackScrollPrev(name=>'TrackScrollPrev'));

    my $hsurf = new SDL::Surface(-width=>690, -height=>50, -depth=>32);
    my $harea = new SDL::Rect(-x=>250, -y=>100, -width=>690, -height=>50);
    my $header = new Widget::Surface(name=>'header', area=>$harea, surface=>$hsurf);
    $this->add_widget($header);
    $this->{headerbgcolor} = new SDL::Color(-r=>160, -g=>160, -b=>160);
    $this->{headerfgcolor} = new SDL::Color(-r=>0, -g=>0, -b=>0);
    $this->{headerfont} = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>20, -bg=>$this->{headerbgcolor}, -fg=>$this->{headerfgcolor});

    my $apbarea = new SDL::Rect(-x=>10, -y=>400, -width=>150, -height=>60);
    my $apb = new Themes::Original::PlayAllButton(name=>'playall', area=>$apbarea);
    $this->add_widget($apb);

    $this->{top} = 0;

    #logger("\n\t".join("\n\t", map { $_->name() } @{$this->widgets()} ));
}

sub show_album_tracks {
    my $this = shift;
    my %o = @_;

    $this->{album} = $o{album};

    if (my $w = $this->get_widget('AlbumCover')) {
        $w->set_album(album=>$this->{album});
    }

    if (my $w = $this->get_widget('playall')) {
        $w->set_album(album=>$this->{album});
    }

    if (my $w = $this->get_widget('header')) {
        my $s = $w->surface();
        my $area = $w->area();
        $this->container()->draw_background(canvas=>$s, dest=>0, source=>$area);
        #$s->fill(0, $this->{headerbgcolor});
        my $xcenter = int($area->width()) / 2;
        my @lines = ($this->{album}->performer(), $this->{album}->name());
        $this->{headerfont}->print_lines_justified(just=>0, surf=>$s, x=>$xcenter, y=>0, lines=>\@lines);
        my $t = new SDL::Rect($area->tohash()); # copy width and height
        $t->x(0);
        $t->y($t->height()-2);
        $s->fill($t, $this->{headerfgcolor});
        $w->redraw();
    }

    my $tracks = $this->{album}->tracklist();
    $this->{top} = 0;
    $this->{max} = scalar @{$tracks};

    print "\nTracks on ".$this->{album}->albumid()."\n";
    my $c = 0;
    foreach my $track (@$tracks) {
        my $w = $this->get_widget("trackselect$c");
        if ($w) {
            if ($c < $this->{onscreen}) {
                $w->set_position(@{$this->{positions}->[$c]});
                $w->visible(1);
            } else {
                $w->visible(0);
            }
            $w->set_track(track=>$track, album=>$this->{album});
        }
        printf('  %4s. %s - %s%s', $track->trackref(), $track->performer(), $track->name(), "\n");
        $c++;
    }
    if ($c < (my $x = scalar @{$this->{positions}} ) ) {
        while ($c < $x) {
            my $w = $this->get_widget("trackselect$c");
            if ($w) {
                $w->set_track(track=>undef, album=>undef);
                $w->visible(0);
            }
            $c++;
        }
    }

    # we're at the top, hide the scroll prev button
    $this->get_widget('TrackScrollPrev')->visible(0);

    # less than a page's worth of tracks, hide the next button
    if (scalar @{$tracks} <= $this->{onscreen}) {
        $this->get_widget('TrackScrollNext')->visible(0);
    } else {
        $this->get_widget('TrackScrollNext')->visible(1);
    }
    print "\n\n";
}

sub scroll_tracks {
    my $this = shift;
    my %o = @_;
    my $dir = $o{direction} || $o{dir};

    return if (!$dir);

    my $trkcnt = scalar @{$this->{album}->tracklist()};
    $trkcnt = MAXTRACKS if ($trkcnt > MAXTRACKS);
    my $max = $trkcnt - $this->{onscreen};

    $this->{top} += $dir;
    $this->{top} = 0 if ($this->{top} < 0);
    $this->{top} = $max if ($this->{top} > $max);
    my @pos = @{$this->{positions}};
    my $cur = 0;
    while($cur < $this->{top}) {
        my $name = "trackselect$cur";
        my $w = $this->get_widget($name);
        $w->visible(0) if ($w);
        $cur++;
    }

    my @positions = @{$this->{positions}};

    my $cpos = 0;
    while($cpos < $this->{onscreen}) {
        last if ($cur > $trkcnt);
        my $name = "trackselect$cur";
        my $w = $this->get_widget($name);
        $w->erase();
        $w->set_position(@{$positions[$cpos]}) if ($w);
        $w->visible(1);
        $cur++;
        $cpos++;
    }

    if ($this->{top} == 0) {
        $this->get_widget('TrackScrollPrev')->visible(0);
        if ($trkcnt > $this->{onscreen}) {
            $this->get_widget('TrackScrollNext')->visible(1);
        }
    } elsif ($this->{top} >= $max) {
        $this->get_widget('TrackScrollPrev')->visible(1);
        $this->get_widget('TrackScrollNext')->visible(0);
    } else {
        $this->get_widget('TrackScrollPrev')->visible(1);
        $this->get_widget('TrackScrollNext')->visible(1);
    }

    while($cur <= MAXTRACKS) {
        my $name = "trackselect$cur";
        my $w = $this->get_widget($name);
        $w->visible(0) if ($w);
        $cur++;
    }
}

1;

