#!/usr/bin/perl

package Themes::Original::RipActionButton;

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

use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>140, -b=>140, -g=>140);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    $this->{face} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->set_frame(frame=>0, surface=>$this->{face}, resize=>0);

    $this->{font} = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{mode} = 'idle';
    $this->update_face($this->{mode});

    $this->{for_device} = $this->{devices}->[0]; 
    my $x = $main::client->devices('read');
    if (scalar @$x) {
        # only handles the first reading device
        $this->{rip_device} = $x->[0];
    }
}

sub update_face {
    my $this = shift;
    my $mode = shift;

    my $msg = $mode eq 'idle' ? 'start' : 'abort';
    $this->{mode} = $mode;
    my $area = $this->area();
    my $fh = $this->{font}->height();

    $this->{face}->fill(0, $this->{bgcolor});

    my $y = ($area->height() - (1 * $fh)) / 2;
    $this->{font}->print_lines_justified(just=>0, surf=>$this->{face}, x=>($area->width()/2), y=>$y, lines=>[$msg]);
    $this->make_depressed_frame();

    $this->redraw();
}

sub onClick {
    my $this = shift;

    #my $mode;
    # toggle the mode
    if ($this->{mode} eq 'idle') {
        # start ripping
        $main::client->rip($this->{rip_device});
        #$mode = 'ripping';
    } else {
        $main::client->abort_rip($this->{rip_device});
        #$mode = 'idle';
    }
    #$this->update_face($mode);
    $this->container()->get_widget('rippinginfo')->update(continuous=>1);

}

1;

