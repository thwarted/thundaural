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

my $max_queued_tracks = 6;

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

    my $somethingplaying = 1;
    my $playtimeleft = 0;

    my(@nowplaying, @queuedup, @mostrecent, $just);
    $this->update_every(1000);
    my @outputs = @{$this->{server}->devices('play')};
    @outputs = (shift @outputs); # just do the first one
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
                if (my $w = $c->get_widget('AlbumCover')) {
                    $w->set_album(album=>new Thundaural::Client::Album(trackref=>$nowtrk->trackref()));
                    $w->visible(1);
                }
                $this->{lasttrackref} = $nowtrk->trackref();
            }
            if (my $c = $this->container()) {
                if (my $sp = $c->get_widget('songprogress')) {
                    my $pct = $nowtrk->percentage();
                    $sp->percent_full($pct / 100);
                    $sp->label(sprintf('%.0f%%, %s remaining', $pct , sectotime($nowtrk->length() - $nowtrk->current(), short=>1)))
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
            push(@nowplaying, $nowtrk->performer());
            push(@nowplaying, $nowtrk->name());
            push(@nowplaying, $nowtrk->album()->name());
            my $rank = ucfirst(english_rank($nowtrk->rank()));
            push(@nowplaying, ($rank eq 'Never played' ? $rank : "Ranked $rank") );
            push(@nowplaying, ' ');
            #$playtimeleft += $nowtrk->length();
        } else {
            my $c = $this->container();
            #$c->get_widget('AlbumCover')->set_album(clear=>1);
            $c->get_widget('AlbumCover')->visible(0);
        }
        my $qdtrks = $this->{server}->queued_on($device);
        if (scalar @$qdtrks) {
            my $nexttrkcnt = 0;
            while(scalar @$qdtrks) {
                my $trk = shift @$qdtrks;
                $playtimeleft += $trk->length();
                if ($nexttrkcnt < $max_queued_tracks) {
                    push(@queuedup, sprintf('%s - %s', $trk->performer(), $trk->name()));
                } elsif (!scalar @$qdtrks) {
                    push(@mostrecent, sprintf('%s - %s', $trk->performer(), $trk->name()));
                }
                $nexttrkcnt++;
            }
            if ($nexttrkcnt > $max_queued_tracks) {
                push(@queuedup, sprintf('...plus %d more', $nexttrkcnt - $max_queued_tracks));
            }
        }
        if (@queuedup) {
            unshift(@queuedup, 'Queued up:');
            push(@queuedup, ' ');
        }
        if (@mostrecent) {
            unshift(@mostrecent, ' ', 'Most recently added:');
        }

        my $rpamt = $this->{server}->random_play_time_remaining($device);
        #$rpamt = 380000;
        if ($playtimeleft || $rpamt) {
            my $x = $playtimeleft > $rpamt ? $playtimeleft : $rpamt;
            # ballpark it to the minute, don't be too exact
            $x = int($x / 60)+1 * 60;
            push(@queuedup, sprintf('About %s of %splay time remaining.', 
                                    Themes::Common::sectotime($x),
                                    $rpamt > $playtimeleft ? 'random ' : '')
                );
        }
        $just = -1;
    }

    my @lines = (@nowplaying, @queuedup, @mostrecent);
    if (! scalar @lines) {
        push(@lines, " ", " ", " ", " ", "Browse albums and pick a track");
        $somethingplaying = 0;
        $just = -1;
    }
    my $x = freeze(\@lines);
    if ($force || $x ne $this->{lastlines}) {
        {
            $this->container()->get_widget('songpause')->visible( ! ! $somethingplaying);
            $this->container()->get_widget('songskip')->visible( ! !$somethingplaying);
            $this->container()->get_widget('songprogress')->visible( ! !$somethingplaying);
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
        my @wrappedlines = $this->{font}->wrap(rect=>$area, lines=>\@lines);
        $this->{font}->print_lines_justified(just=>$just, surf=>$s, x=>$xpos, y=>0, lines=>\@wrappedlines, maxwidth=>$area->width()-10, wrap=>1);
        $this->surface($s);
        $this->{lastlines} = $x;
        return 1;
    } else {
        logger("no differences at %d", $ticks);
    }
    return 0;
}

1;

