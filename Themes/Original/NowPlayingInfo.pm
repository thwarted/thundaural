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

use base 'Widget::Surface';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();
    $this->update_every(50);

    $this->{server} = $main::client;

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>140, -g=>140);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    #my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    #$this->surface($s);

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

    $this->update_every(2100);
    my @outputs = @{$this->{server}->devices('play')};
    @outputs = (shift @outputs); # just do the first one
    my @lines = ();
    foreach my $device (@outputs) {
        #{
            #my $volume = $this->{server}->volume($device);
            #my $c = $this->container();
            #my $w = $c->get_widget("volumeselect");
            #$w->percent_full($volume);
        #}
        my $nowtrk = $this->{server}->playing_on($device);
        if ($nowtrk) {
            # we're only doing the first entry, this is good, since there is only one coverart
            if ($this->{lasttrackref} ne $nowtrk->trackref()) {
                my $c = $this->container();
                $c->get_widget('AlbumCover')->set_album(album=>new Thundaural::Client::Album(trackref=>$nowtrk->trackref()));
                $this->{lasttrackref} = $nowtrk->trackref();
            }
            $nowtrk = $nowtrk->tohash();
            foreach my $k (keys %$nowtrk) {
                push(@lines, sprintf('%s: %s', $k, $nowtrk->{$k}));
            }
        }
        my $qdtrks = $this->{server}->queued_on($device);
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
    }
    my $x = freeze(\@lines);
    if ($force || $x ne $this->{lastlines}) {
        my $area = $this->area();
        my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
        $s->fill(0, $this->{bgcolor});
        $this->{font}->print_lines_justified(just=>-1, surf=>$s, x=>0, y=>0, lines=>\@lines);
        $this->surface($s);
        $this->{lastlines} = $x;
        return 1;
    }
    return 0;
}

1;

