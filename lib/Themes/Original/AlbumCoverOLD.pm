#!/usr/bin/perl

package Themes::Original::AlbumCover;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Rect;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Themes::Original::AlbumCoverBase;
use base 'Themes::Original::AlbumCoverBase';

#$SIG{'__DIE__'} = sub { use Carp; confess(@_); };

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    my $area = new SDL::Rect(-x=>10, -y=>105, -height=>230, -width=>230);
    $this->area($area);

    $this->SUPER::widget_initialize(@_);

    $this->set_onClick( sub { $main::theme->show_page('AlbumsPage'); } );
}

1;

