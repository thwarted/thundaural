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

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();
    $this->update_every(1000);

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>160, -g=>160);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);

    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>49, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{lastupdate} = 0;
    $this->{lastlines} = '';

}

sub update {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};
    my $force = $o{force};

    $this->update_every(30000);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
    my @lines = ();
    push(@lines, sprintf('%d:%02d %s', ($hour < 12 ? ($hour ? $hour : 12 ) : $hour - 12), $min, ($hour < 12 ? 'am' : 'pm')));

    my $x = freeze(\@lines);
    if ($force || $x ne $this->{lastlines}) {
        my $area = $this->area();
        my $s = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
        $s->fill(0, $this->{bgcolor});
        $this->{font}->print_lines_justified(just=>-1, surf=>$s, x=>0, y=>0, lines=>\@lines, maxwidth=>$area->width()-10);
        $this->surface($s);
        $this->{lastlines} = $x;
        return 1;
    }
    return 0;
}

1;

