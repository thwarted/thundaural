#!/usr/bin/perl

package Themes::Original::StatsInfo;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::TTFont;
use Storable qw(freeze);
use POSIX qw(strftime);

use Thundaural::Logger qw(logger);
use Widget::Surface;

use base 'Widget::Surface';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();
    $this->update_every(50);

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>160, -g=>160);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->surface($s);

    $this->{font} = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{lastupdate} = 0;
    $this->{lastdata} = '';

}

sub update {
    my $this = shift;
    my %o = @_;
    my $force = $o{force};

    my $st = $main::client->stats();
    my $ss = freeze($st);

    if ($force || $this->{lastdata} ne $ss) {
        $this->draw_info(data=>$st);
        $this->{lastdata} = $ss;
        return 1;
    }
    return 0;
}

sub draw_info {
    my $this = shift;
    my %o = @_;
    my $st = $o{data};

    $this->update_every(15000);

    my $supsince = time() - $st->{'uptime-server'};
    my $mupsince = time() - $st->{'uptime-machine'};
    my $cupsince = time() - $st->{'uptime-client'};
    delete($st->{'uptime-server'});
    delete($st->{'uptime-machine'});
    delete($st->{'uptime-client'});

    my $g = 10;
    my @lines = ();
    my $x;

    $x = $st->{albums} || 0;
    push(@lines, $x ? sprintf('%d album%s', $x, ($x == 1 ? '' : 's')) : 'No albums' );

    if ($x = (($st->{albums} || 0) - ($st->{coverartfiles} || 0)) ) {
        push(@lines, sprintf('%d album%s %s missing cover art', $x, ($x == 1 ? '' : 's') , ($x == 1 ? 'is' : 'are') ));
    } else {
        push(@lines, "");
    }
    push(@lines, "");
    $x = $st->{tracks} || 0; 
    push(@lines, $x ? ($x == 1 ? '1 track' : "$x total tracks") : 'No tracks' );
    $x = $st->{'tracks-played'};
    push(@lines, sprintf("\t%s tracks successfully played", ($x ? $x : 'No') ));
    $x = $st->{'tracks-skipped'} || 0;
    push(@lines, sprintf("\t%s tracks skipped", ($x ? $x : 'No') ));
    $x = $st->{'tracks-failed'} || 0;
    push(@lines, sprintf("\t%s tracks have had problems playing", ($x ? $x : 'No') ));
    push(@lines, "");
    push(@lines, sprintf("%s total storage space", $this->short_mem($st->{'storage-total'})));
    push(@lines, sprintf("\t%s used", $this->short_mem($st->{'storage-used'})));
    push(@lines, sprintf("\t%s available", $this->short_mem($st->{'storage-available'})));
    push(@lines, "");
    push(@lines, sprintf("Server machine up since %s", strftime('%a %b %e %H:%M:%S %Y', localtime($mupsince))));
    push(@lines, sprintf("Server software up since %s", strftime('%a %b %e %H:%M:%S %Y', localtime($supsince))));
    push(@lines, sprintf("Client connected since %s", strftime('%a %b %e %H:%M:%S %Y', localtime($cupsince))));

    #print "\n".join("\n", @lines)."\n";

    my $area = $this->area();
    my $surf = $this->surface();
    $this->container()->draw_background(canvas=>$surf, dest=>0, source=>$area);
    $this->{font}->print_lines_justified(just=>-1, surf=>$surf, x=>10, y=>10, lines=>\@lines);

    {
        my $c = $this->container();
        my $w = $c->get_widget('diskspace');
        $w->percent_full($st->{'storage-percentagefull'}/100);
        $w->label(sprintf('storage space - %d%% full', $st->{'storage-percentagefull'}));
    }
}

sub short_mem {
    my $this = shift;
    my $a = shift;

    my $k = $a / 1024;
    my $m = $k / 1024;
    my $g = $m / 1024;

    if ($g > 1) {
        return sprintf('%.1f gigabytes', $g);
    }
    if ($m > 1) {
        return sprintf('%.1f megabytes', $m);
    }
    if ($k > 1) {
        return sprintf('%.1f kilobytes', $k);
    }
    return "$a bytes";
}


1;

