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

my $max_queued_tracks = 10;

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();
    $this->update_every(50);

    $this->{surface} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->surface($this->{surface});

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>160, -g=>160);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);

    $this->{font} = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>17, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{lastupdate} = 0;
    $this->{lasttrackref} = 0;
    $this->{lastlines} = '';
    $this->{lastdata} = '';
}

sub update {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};
    my $force = $o{force};

    $this->update_every(1000);
    my $s = {};

    my @outputs = @{$main::client->devices('play')};
    @outputs = (shift @outputs); # just do the first one
    my $sf = '';
    foreach my $device (@outputs) { # this loop should only execute once
        $s->{volume} = $main::client->volume($device);
        $s->{track} = $main::client->playing_on($device);
        $s->{queued} = $main::client->queued_on($device);
        $s->{device} = $device;
        $sf = join(',', $s->{volume}, ($s->{track} ? $s->{track}->trackref() : 0), $s->{device}, map { $_->trackref() } @{$s->{queued}} );

        if (my $nowtrk = $s->{track}) {
            my $c = $this->container();
            if (my $sp = $c->get_widget('songprogress')) {
                my $pct = $nowtrk->percentage();
                $sp->percent_full($pct / 100);
                $sp->label(sprintf('%.0f%%, %s remaining', $pct , sectotime($nowtrk->length() - $nowtrk->current(), short=>1)))
            }
        }
    }

    if ($force || $sf ne $this->{lastdata}) {
        $this->{lastdata} = $sf;
        $this->draw_info(data=>$s);
        return 1;
    }
    return 0;
}

sub draw_info {
    my $this = shift;
    my %o = @_;
    my $s = $o{data};

    my(@nowplaying, @timeleft, @queuedup, @mostrecent, $just);
    my $somethingplaying = 1;
    my $playtimeleft = 0;
    my $device = $s->{device};

    my $container = $this->container();
    if (my $nowtrk = $s->{track}) {
        # we're only doing the first entry, this is good, since there is only one cover art
        if ($this->{lasttrackref} ne $nowtrk->trackref()) {
            my $c = $this->container();
            if (my $w = $c->get_widget('AlbumCover')) {
                $w->set_album(album=>new Thundaural::Client::Album(trackref=>$nowtrk->trackref()));
                $w->visible(1);
            }
            $this->{lasttrackref} = $nowtrk->trackref();
        }
        if (my $vm = $container->get_widget('volumeselect')) {
            $vm->percent_full($nowtrk->volume() / 100);
        }
        push(@nowplaying, $nowtrk->performer());
        push(@nowplaying, $nowtrk->name());
        push(@nowplaying, $nowtrk->album()->name());
        my $rank = ucfirst(english_rank($nowtrk->rank()));
        push(@nowplaying, ($rank eq 'Never played' ? $rank : "Ranked $rank") );
        push(@nowplaying, ' ');
        #$playtimeleft += $nowtrk->length();
    } else {
        $container->get_widget('AlbumCover')->visible(0);
        my $volume = $s->{volume};
        $container->get_widget('volumeselect')->percent_full($volume / 100);
    }
    my $qdtrks = $s->{queued};
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

    my $rpamt = $main::client->random_play_time_remaining($device);
    if ($playtimeleft || $rpamt) {
        my $x = $playtimeleft > $rpamt ? $playtimeleft : $rpamt;
        # ballpark it to the minute, don't be too exact
        $x = (int($x / 60)+1) * 60;
        push(@timeleft, sprintf('About %s of %splay time remaining.', 
                                Themes::Common::sectotime($x),
                                $rpamt > $playtimeleft ? 'random ' : '')
            );
    }
    if (@timeleft) {
        push(@timeleft, ' ');
    }
    $just = -1;

    my @lines = (@nowplaying, @timeleft, @queuedup, @mostrecent);
    if (! scalar @lines) {
        my $msg = "Browse albums and pick a track";
        if ($main::client->albums_count() == 0) {
            $msg = "Use the rip icon to add albums";
        }
        push(@lines, " ", " ", " ", " ", $msg);
        $somethingplaying = 0;
        $just = -1;
    }

    {
        $this->container()->get_widget('songpause')->visible( ! ! $somethingplaying);
        $this->container()->get_widget('songskip')->visible( ! ! $somethingplaying);
        $this->container()->get_widget('songprogress')->visible( ! !$somethingplaying);
    }
    if ((my $ll = freeze(\@lines)) ne $this->{lastlines}) {
        logger("lines are different");
        my $area = $this->area();
        my $xpos;
        if ($just == -1) {
            $xpos = 0;
        } else {
            $just = 0;
            $xpos = $area->width() / 2;
        }
        my $surf = $this->surface();
        $this->container()->draw_background(canvas=>$surf, dest=>0, source=>$area);
        my @wrappedlines = $this->{font}->wrap(rect=>$area, lines=>\@lines);
        $this->{font}->print_lines_justified(just=>$just, surf=>$surf, x=>$xpos, y=>0, lines=>\@wrappedlines, maxwidth=>$area->width()-10, wrap=>1);
        $this->{lastlines} = $ll;
    }
}

1;

