#!/usr/bin/perl

package Themes::Original::VolumeSelect;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::Event;

use Thundaural::Logger qw(logger);

use Widget::ProgressBar;
use base 'Widget::ProgressBar';

sub onClick {
    my $this = shift;
    my %o = @_;

    $this->percent_full($o{percentage});
}

1;
