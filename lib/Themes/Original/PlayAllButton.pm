#!/usr/bin/perl

package Themes::Original::PlayAllButton;

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
    $this->{face}->fill(0, $this->{bgcolor});

    my $font = new SDL::TTFont(-name=>"media/fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});
    $this->{device} = $o{device};

    my @lines = ('play entire', 'album');
    my $fh = $font->height();
    my $fw = $font->width($lines[0]);
    my $y = ($area->height() - ((scalar @lines) * $fh)) / 2;
    $font->print_lines_justified(just=>0, surf=>$this->{face}, x=>($area->width()/2), y=>$y, lines=>\@lines);

    $this->set_frame(frame=>0, surface=>$this->{face}, resize=>0);
    $this->make_depressed_frame();
    $this->redraw();

    $this->{album} = undef;
}

sub set_album {
    my $this = shift;
    my %o = @_;
    my $album = $o{album};

    if (eval { $album->isa('Thundaural::Client::Album') } ) {
        $this->{album} = $album;
    }
}

sub onClick {
    my $this = shift;

    logger("got click");
    if (eval { $this->{album}->isa('Thundaural::Client::Album') } ) {
        my $dev = $main::client->devices('play');
        my $playon = shift @$dev;
        $this->{album}->play($playon);
        $main::theme->show_page('NowPlayingPage');
    }
}

1;

