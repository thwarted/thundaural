#!/usr/bin/perl

package Themes::Original::RipperInfo;

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
    $this->update_every(1000);

    $this->{devices} = $main::client->devices('read');

    $this->{bgcolor} = new SDL::Color(-r=>160, -b=>160, -g=>160);
    $this->{fgcolor} = new SDL::Color(-r=>0, -b=>0, -g=>0);
    my $surf = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->surface($surf);

    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>17, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{lookingforchange} = 0;
    $this->{laststate} = 0;
    $this->{lastupdate} = 0;
    $this->{lastdata} = '';
    $this->{lasttrackref} = 0;
}

sub update {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};
    my $force = $o{force};
    my $continuous = $o{continuous};

    my $dev = $this->{devices}->[0]; # only handles the first reading device
    my $s = $main::client->status_of($dev);
    my $frozen = freeze($s);

    if ($continuous) {
        $this->update_every(1000);
        $force = 1;
    }

    if ($this->{laststate} ne 'idle' && $s->{state} eq 'idle') {
        $this->update_every(5000);
        $force = 1;
    }

    if ($force || $frozen ne $this->{lastdata}) {
        $this->draw_info(ticks=>$o{ticks}, data=>$s);
        $this->{lastdata} = $s;
        $this->{laststate} = $s->{state};
        return 1;
    }
    return 0;
}

sub draw_info {
    my $this = shift;
    my %o = @_;
    my $s = $o{data};
    my $ticks = $o{ticks};

    my @lines = ();

    if ($s->{state} eq 'idle') {
        $this->container()->get_widget('ripaction')->update_face('idle');
        $this->container()->get_widget('ripprogress')->visible(0);
        push(@lines, "Insert a disc and hit the start button to rip.");
        push(@lines, " ", $s->{volume}, " ") if ($s->{volume});
        if (defined($s->{volume}) && $s->{volume} =~ /successful/) {
            $main::client->clear_cache();
            if (my $w = $this->container()->container()->get_widget('AlbumsPage')) {
                $w->update_albumbuttons();
            }
        }
    } else {
        $this->container()->get_widget('ripaction')->update_face('ripping');
        if (defined($s->{trackref}) && ($s->{trackref} =~ m/\//)) {
            my($ct, $tt) = $s->{trackref} =~ m/(\d+)\/(\d+)/;
            push(@lines, sprintf('Ripping track %d of %s %s', $ct, $tt, $s->{volume}));
            push(@lines, ' ');
            push(@lines, sprintf('%s - %s', $s->{performer}, $s->{name}));
            push(@lines, Themes::Common::sectotime($s->{length}));
            push(@lines, ' ');
            my $ststr = strftime '%H:%M:%S', localtime($s->{started});
            push(@lines, sprintf('started ripping at %s', $ststr));
            my $progress = $this->container()->get_widget('ripprogress');
            $progress->visible(1);
            $progress->percent_full($s->{percentage} / 100);
            $progress->label(sprintf('%d%% - speed %.1fx', $s->{percentage}, $s->{speed}));
        } else {
            push(@lines, sprintf('%s ', $s->{volume}));
        }
    }

    push(@lines, ' ');

    #foreach my $k (keys %{$s}) {
        #push(@lines, "$k: ".(defined($s->{$k}) ? $s->{$k} : 'none') );
    #}

    my $area = $this->area();
    my $surf = $this->surface();
    $this->container()->draw_background(canvas=>$surf, dest=>0, source=>$area);
    $this->{font}->print_lines_justified(just=>0, surf=>$surf, x=>$area->width()/2, y=>0, lines=>\@lines, wrap=>1);

    if (my $ac = $this->container()->get_widget('AlbumCover')) {
        $ac->set_album(album=>'ripping', rippedat=>$s->{started});
    }
}

1;

