#!/usr/bin/perl

package Themes::Base;

use strict;
use warnings;

use Carp qw(cluck confess);
use Data::Dumper;

use Thundaural::Logger qw(logger);

sub new {
    my $this = shift;
    my %o = @_;
    my $class = ref($this) || $this;
    $this = {} if (ref($this) eq '');
    bless $this, $class;

    $this->{_t}->{blitqueue} = [];
    $this->{_t}->{bgcolor} = undef;
    $this->{_t}->{bgimage} = undef;
    $this->{_t}->{widgets} = {};

    $this->name($o{name}) if ($o{name});

    $this->theme_initialize();

    return $this;
}

sub theme_initialize {
    return 0;
}

sub start {
    my $this = shift;
    my $widgets = $this->widgets();
    foreach my $widget (@$widgets) {
        $widget->start();
    }
    return 1;
}

sub stop {
    return 1;
}

sub heartbeat {
    return 0;
}

sub add_widget {
    my $this = shift;

    my $c = 0;
    foreach my $widget (@_) {
        my $name = $widget->name();
        #logger("added $name ($widget)");
        $this->{_t}->{widgets}->{$name} = $widget;
        $widget->theme($this);
        $c++;
    }
    return $c;
}

sub request_blit {
    my $this = shift;
    my %o = @_;
    my $name = $o{name};
    my $surface = $o{surface};
    my $area = $o{area};
    my $sync = $o{sync} || 0;

    if ($surface && $area) {
        #cluck(sprintf("queueing $name ($surface) at %d,%d %dx%d", $area->x, $area->y, $area->width, $area->height));
        push(@{$this->{_t}->{blitqueue}}, [$name, $surface, $area, $sync]);
        return 1;
    } else {
        cluck("surface ($surface) or area ($area) are false for $name");
    }
    return 0;
}

sub get_blit {
    my $this = shift;
    my %o = @_;

    my $numblits = scalar @{$this->{_t}->{blitqueue}};
    if (!$numblits) {
        if (!$this->draw_widgets(@_)) {
            return ();
        }
    }
    my $x = shift(@{$this->{_t}->{blitqueue}});
    if (ref($x) eq 'ARRAY') {
        return @$x;
    }
    return ();
}

sub draw_widgets {
    my $this = shift;
    my %o = @_;

    my $c = 0;
    foreach my $widget (values %{$this->{_t}->{widgets}} ) {
        $c++ if ($widget->draw(@_));
    }
    return $c;
}

sub bgcolor {
    my $this = shift;
    my $color = shift;

    my $oldcolor = $this->{_t}->{bgcolor};
    if ($color) {
        $this->{_t}->{bgcolor} = $color;
    }
    return $oldcolor;
}

sub receive_event {
    my $this = shift;

    foreach my $widget (values %{$this->{_t}->{widgets}}) {
        $widget->receive_event(@_);
    }
}

sub get_widget {
    my $this = shift;
    my $name = shift;
    return $this->{_t}->{widgets}->{$name};
}

sub widgets {
    my $this = shift;
    return [values %{$this->{_t}->{widgets}} ];
}

sub hide_widget {
    my $this = shift;
    my $wname = shift;
    my $widget = $this->get_widget($wname);
    return 0 if (!$widget);
    $widget->visible(0);
    $this->erase_area($widget->area());
}

sub show_widget {
    my $this = shift;
    my $wname = shift;
    my $widget = $this->get_widget($wname);
    return 0 if (!$widget);
    $widget->visible(1);
    $this->erase_area($widget->area());
    $widget->redraw();
}

sub widget_toggle_visible {
    my $this = shift;
    my $wname = shift;

    my $widget = $this->get_widget($wname);
    return 0 if (!$widget);
    $widget->toggle_hidden();
    if (!$widget->visible()) {
        $this->erase_area($widget->area());
    }
}

sub erase_area {
    my $this = shift;
    my $area = shift;

    my $a = new SDL::Rect($area->tohash());
    $this->request_blit(name=>"_bg", surface=>'background', area=>$a);
    return;

    #if (my $bgimage = $this->bgimage()) {
    #    #logger('requesting bg redraw at %d,%d %dx%d', $area->x(), $area->y(), $area->width(), $area->height());
    #    $this->request_blit(name=>'_bg', surface=>'background', area=>$a);
    #} elsif (my $wbg = $this->{_t}->{bgcolor}) {
    #    my $sur = new SDL::Surface(-width=>$a->width(), -height=>$a->height(), -depth=>24);
    #    logger("drawing bgcolor");
    #    $sur->fill(0, $wbg);
    #} else {
    #    confess("neither background color or image is set");
    #}
}

sub bgimage {
    my $this = shift;

    if (@_) {
        $this->{_t}->{bgimage} = shift;
    }
    return $this->{_t}->{bgimage};
}

sub draw_background {
    my $this = shift;
    my %o = @_;
    my $canvas = $o{canvas};
    my $dest = $o{dest};
    my $source = $o{source};

    if (!defined($dest)) {
        $dest = $source;
    }

    my $s = $source ? new SDL::Rect($source->tohash()) : 0;
    my $d = $dest ? new SDL::Rect($dest->tohash()) : 0;

    if (my $bgimage = $this->bgimage() ) {
        $bgimage->display_format();
        $bgimage->blit($s, $canvas, $d);
    } elsif (my $bgcolor = $this->{_t}->{bgcolor}) {
        $canvas->fill($d, $bgcolor);
    }
    return 1;
}

sub redraw {
    my $this = shift;
    my $area = shift;

    $this->erase_area($area);
    my $subwidgets = $this->widgets();
    foreach my $widget (@{$subwidgets}) {
        $widget->redraw();
    }
}

1;

