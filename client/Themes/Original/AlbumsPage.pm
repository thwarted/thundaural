#!/usr/bin/perl

package Themes::Original::AlbumsPage;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;

use SDL;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Widget::Group;

use base 'Widget::Group';

use Themes::Original::AlbumPrev;
use Themes::Original::AlbumNext;
use Themes::Original::AlbumSelect;
use Themes::Original::AlbumSlider;

sub widget_initialize {
    my $this = shift;

    $this->SUPER::widget_initialize(@_);

    $this->add_widget(new Themes::Original::AlbumPrev(name=>'albumprev'));
    $this->add_widget(new Themes::Original::AlbumNext(name=>'albumnext'));
    $this->add_widget(new Themes::Original::AlbumSlider(name=>'albumslider'));

    $this->{album_offset} = 0;

    my $positions = [ 
                        #[   2,120, 50],
                        #[   2,410, 50],
                        [  91,102,275],
                        [  91,386,275],
                        [ 375,102,275],
                        [ 375,386,275],
                        [ 659,102,275],
                        [ 659,386,275]
                    ]; # 275x275
    $this->{albums_per_page} = scalar @{$positions};

    my $o = 0; # $this->{album_offset};
    my $c = 0;
    my $start_albums = $main::client->albums(offset=>$this->{album_offset}, count=>$this->{albums_per_page});
    $this->{albumbuttons} = [];
    foreach my $pos (@{$positions}) {
        my($x, $y, $s) = @$pos;
        my $p = new SDL::Rect(-x=>$x, -y=>$y, -width=>$s, -height=>$s);
        my $name = "albumselect$c";
        my $w = new Themes::Original::AlbumSelect(name=>$name, area=>$p, album=>$start_albums->[$o]);
        $this->add_widget($w);
        push(@{$this->{albumbuttons}}, $name);
        $c++;
        $o++;
    }
}

sub start {
    my $this = shift;

    $this->SUPER::start();
    $this->hide_nav_buttons();
}

sub page_size {
    my $this = shift;

    return $this->{albums_per_page};
}

sub total_albums {
    my $this = shift;
    my $total = $main::client->albums_count();
    return $total;
}

sub adjust_album_offset {
    my $this = shift;
    my %o = @_;
    my $change = $o{change};
    my $pct = $o{percentage};
    my $page = $o{page};

    my $offset = $this->{album_offset};
    my $ooffset = $offset;
    my $total = $main::client->albums_count();
    if (defined($change)) {
        $offset += $change;
        if ($offset < 0) {
            $offset = 0;
        }
    } elsif (defined($page)) {
        $offset += ($this->{albums_per_page} * $page);
    } elsif (defined($pct)) {
        $offset = int($total * $pct);
    } else {
        croak("adjust_album_offset(change=>INT, percentage=>FLOAT, page=>INT)");
    }
    my $max = $total - $this->{albums_per_page};
    $offset = $max if ($offset > $max);
    $offset = 0 if ($offset < 0);
    $this->{album_offset} = $offset;
    if ($ooffset != $offset) {
        # only go through the trouble of updating the buttons if
        # we actually changed
        $this->update_albumbuttons();
        $this->hide_nav_buttons();
        my $pct = $total <= 0 ? 0 : ($offset / $total);
        $pct = 1.0 if ($pct > 1.0);
        if ($pct >= ($max / $total)) {
            $pct = 1;
        }
        if ($pct < (1 / $total)) {
            $pct = 0;
        }
        $this->get_widget('albumslider')->percent_full($pct);
        logger("album offset is $offset");
    }
}

sub hide_nav_buttons {
    my $this = shift;
    
    my $offset = $this->{album_offset};
    my $total = $main::client->albums_count();
    my $max = $total - $this->{albums_per_page};

    if ($offset == 0 && $total < scalar @{$this->{albumbuttons}}) {
        $this->get_widget('albumprev')->visible(0);
        $this->get_widget('albumnext')->visible(0);
        $this->get_widget('albumslider')->visible(0);
    } elsif ($offset == 0) {
        $this->get_widget('albumprev')->visible(0);
        $this->get_widget('albumnext')->visible(1);
        $this->get_widget('albumslider')->visible(1);
    } elsif ($offset >= $max) {
        $this->get_widget('albumprev')->visible(1);
        $this->get_widget('albumnext')->visible(0);
        $this->get_widget('albumslider')->visible(1);
    } else {
        $this->get_widget('albumprev')->visible(1);
        $this->get_widget('albumnext')->visible(1);
        $this->get_widget('albumslider')->visible(1);
    }
}

sub update_albumbuttons {
    my $this = shift;
    my $offset = $this->{album_offset};

    my $page_albums = $main::client->albums(offset=>$offset, count=>$this->{albums_per_page});
    my @buttons = @{$this->{albumbuttons}};
    map {
        my $w = $this->get_widget(shift @buttons);
        $w->set_album(album=>$_);
        $w->visible(1);
    } @{$page_albums};
}

1;

    #my $s = new SDL::Surface(-width=>600, -height=>600, -depth=>24, -flags=>SDL_SRCALPHA | SDL_SWSURFACE);
    #$s->rgb();
    #$s->fill(0, new SDL::Color(-r=>128, -g=>128, -b=>128));
    #$s->set_alpha(SDL_SRCALPHA, 128);
    #$this->{buttonfade} = $s;

