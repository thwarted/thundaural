#!/usr/bin/perl

package Widget::Group;

# a widget that is a container for other widgets
# allowing the subwidgets to be controlled as a group

use strict;
use warnings;

use Data::Dumper;
use Carp qw(cluck confess);

use Thundaural::Logger qw(logger);

use Widget::Base;
use Themes::Base;

our @ISA = qw(Widget::EventReceiver Themes::Base);

sub new {
    my $this = shift;
    my %o = @_;
    my $class = ref($this) || $this;
    $this = {} if (ref($class) eq '');
    bless $this, $class;

    $this->{_wg}->{lasttickdraw} = 0;

    $this->Themes::Base::new(@_);
    $this->Widget::Base::new(@_);

    return $this;
}

sub start {
    my $this = shift;
    $this->Themes::Base::start();
    $this->area(); # calculate area
    #$this->bgcolor($this->theme()->bgcolor());
    #$this->bgimage($this->theme()->bgimage());
}

sub widget_initialize {
    my $this = shift;

    $this->Themes::Base::theme_initialize(@_);
    $this->Widget::Base::widget_initialize(@_);
}

sub area {
    my $this = shift;

    my $a = $this->Widget::EventReceiver::area();
    if (!$a) {
        my $subwidgets = $this->widgets();
        if (scalar @$subwidgets) {
            my($minx, $miny, $maxx, $maxy) = (1024,768,0,0);
            foreach my $widget (@{$subwidgets}) {
                #print "adding area of $widget\n";
                my $area = $widget->area();
                next if (!$area);
                $minx = &_min($minx, $area->x());
                $miny = &_min($miny, $area->y());
                $maxx = &_max($maxx, $area->x() + $area->width());
                $maxy = &_max($maxy, $area->y() + $area->height());
            }
            my $width = $maxx - $minx;
            my $height = $maxy - $miny;
            #logger('%s area is %d,%d  %dx%d', $this->{name}, $minx, $miny, $width, $height);
            $a = new SDL::Rect(-x=>$minx, -y=>$miny, -width=>$width, -height=>$height);
            $this->Widget::EventReceiver::area($a);
        } else {
            return undef;
        }
    }
    return $a;
}

sub _min {
    my($a, $b) = @_;
    return $a < $b ? $a : $b;
}

sub _max {
    my($a, $b) = @_;
    return $a > $b ? $a : $b;
}

sub should_draw {
    my $this = shift;
    my $ticks = shift;

    return 0 if (!$this->visible());
    return 1;
}

sub request_blit {
    my $this = shift;
    my %o = @_;
    $o{sync} = 0;
    return $this->Widget::Base::request_blit(%o);
}

sub draw {
    my $this = shift;
    my %o = @_;

    return 0 if (!$this->should_draw(@_));
    $this->Themes::Base::draw_widgets(@_);
}

sub redraw {
    my $this = shift;

    my $subwidgets = $this->widgets();
    foreach my $widget (@{$subwidgets}) {
        $widget->redraw();
    }
}

sub receive_event {
    my $this = shift;
    return 0 if (!$this->visible());
    $this->Themes::Base::receive_event(@_);
}

sub erase_area {
    my $this = shift;

    my $t = $this->theme();
    $t->erase_area(@_);
}

sub get_widget {
    my $this = shift;

    my $w = $this->SUPER::get_widget(@_);
    if (!$w) {
        my $t = $this->theme();
        $w = $t->get_widget(@_);
    }

    return $w;
}

1;

