#!/usr/bin/perl

package Themes::Original::Clock;

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

my $show_seconds = 0;

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();
    $this->update_every(1000);

    $this->{bgcolor} = new SDL::Color(-r=>170, -g=>170, -b=>170);
    $this->{fgcolor} = new SDL::Color(-r=>0, -g=>0, -b=>0);

    my $fontsize;
    $fontsize = $show_seconds ? 40 : 49;
    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>$fontsize, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{surface} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->surface($this->{surface});

    $this->{lastupdate} = 0;
    $this->{lastlines} = '';

}

sub update {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};
    my $force = $o{force};

    $this->update_every($show_seconds ? 1000 : 30000);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
    my @lines = ();
    my $msg;
    if ($show_seconds) {
        $msg = sprintf('%d:%02d:%02d %s', ($hour < 12 ? ($hour ? $hour : 12 ) : $hour - 12), $min, $sec, ($hour < 12 ? 'am' : 'pm'));
    } else {
        $msg = sprintf('%d:%02d %s', ($hour < 12 ? ($hour ? $hour : 12 ) : $hour - 12), $min, ($hour < 12 ? 'am' : 'pm'));
    }
    push(@lines, $msg);

    my $x = freeze(\@lines);
    if ($force || $x ne $this->{lastlines}) {
        my $area = $this->area();
        my $surf = $this->surface();
        $this->container()->draw_background(canvas=>$surf, dest=>0, source=>$area);
        $this->{font}->print_lines_justified(just=>-1, surf=>$surf, x=>0, y=>0, lines=>\@lines, maxwidth=>$area->width()-10);
        $this->{lastlines} = $x;
        return 1;
    }
    return 0;
}

1;

