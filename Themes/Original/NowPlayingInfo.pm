#!/usr/bin/perl

package Themes::Original::NowPlayingInfo;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::TTFont;
use Storable qw(freeze);

use Thundaural::Logger qw(logger);
use Widget::Surface;
use Themes::Common qw(sectotime english_rank);

use base 'Widget::Surface';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();
    $this->update_every(50);

    $this->{server} = $main::client;

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>160, -g=>160);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);

    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>17, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{lastupdate} = 0;
    $this->{lastlines} = '';
    $this->{lasttrackref} = 0;

}

sub draw_info {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};
    my $force = $o{force};

    $this->update_every(1000);
    my @outputs = @{$this->{server}->devices('play')};
    @outputs = (shift @outputs); # just do the first one
    my @lines = ();
    my $somethingplaying = 1;
    my $just;
    foreach my $device (@outputs) {
        {
            my $volume = $this->{server}->volume($device);
            my $c = $this->container();
            my $w = $c->get_widget("volumeselect");
            $w->percent_full($volume / 100);
        }
        my $nowtrk = $this->{server}->playing_on($device);
        if ($nowtrk) {
            # we're only doing the first entry, this is good, since there is only one cover art
            if ($this->{lasttrackref} ne $nowtrk->trackref()) {
                my $c = $this->container();
                $c->get_widget('AlbumCover')->set_album(album=>new Thundaural::Client::Album(trackref=>$nowtrk->trackref()));
                $this->{lasttrackref} = $nowtrk->trackref();
            }
            if (my $c = $this->container()) {
                if (my $sp = $c->get_widget('songprogress')) {
                    my $pct = $nowtrk->percentage();
                    $sp->percent_full($pct);
                    $sp->label(sprintf('%.0f%%, %s remaining', $pct * 100, sectotime($nowtrk->length() - $nowtrk->current(), my $short = 1)))
                }
                if (my $vm = $c->get_widget('volumeselect')) {
                    $vm->percent_full($nowtrk->volume() / 100);
                }
            }
            #$nowtrk = $nowtrk->tohash();
            #foreach my $k (keys %$nowtrk) {
            #    next if ($k =~ m/percentage/);
            #    next if ($k =~ m/current/);
            #    next if ($k =~ m/volume/);
            #    push(@lines, sprintf('%s: %s', $k, $nowtrk->{$k}));
            #}
            push(@lines, $nowtrk->performer());
            push(@lines, $nowtrk->name());
            push(@lines, $nowtrk->album()->name());
            my $rank = ucfirst(english_rank($nowtrk->rank()));
            push(@lines, sprintf('Ranked %s', $rank) );
        }
        my $qdtrks = $this->{server}->queued_on($device);
        if (scalar @$qdtrks) {
            my $c = 0;
            push(@lines, " ", "Queued up:");
            while(scalar @$qdtrks) {
                my $trk = shift @$qdtrks;
                push(@lines, sprintf('    %s - %s', $trk->performer(), $trk->name()));
                $c++;
                last if ($c > 4);
            }
            if (my $x = (scalar @$qdtrks)) {
                push(@lines, sprintf(' ... plus %d more', $x));
            }
            $just = -1;
        }
    }
    if (! scalar @lines) {
        push(@lines, " ", " ", " ", " ", "Browse albums and pick a track");
        $somethingplaying = 0;
        $just = 0;
    }
    my $x = freeze(\@lines);
    if ($force || $x ne $this->{lastlines}) {
        { # this should really be moved to logic on the button itself
            $this # this widget is at the top level
                ->container()
                ->container()
                ->get_widget('IconNowPlaying')
                ->animate($somethingplaying * 500);
        };
        my $area = $this->area();
        my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
        my $xpos;
        if ($just == -1) {
            $xpos = 0;
        } else {
            $just = 0;
            $xpos = $area->width() / 2;
        }
        $s->fill(0, $this->{bgcolor});
        $this->{font}->print_lines_justified(just=>$just, surf=>$s, x=>$xpos, y=>0, lines=>\@lines, maxwidth=>$area->width()-10);
        $this->surface($s);
        $this->{lastlines} = $x;
        return 1;
    }
    return 0;
}

1;

