#!/usr/bin/perl

package Widget::EventReceiver;

use strict;
use warnings;

use Carp;
use Data::Dumper;

use SDL;
use SDL::Event;

use Thundaural::Logger qw(logger);

use Widget::Base;
use base 'Widget::Base';

sub new {
    my $this = shift;
    my %o = @_;
    my $class = ref($this) || $this;
    $this = {} if (ref($this) eq '');
    bless $this, $class;

    $this->{_e} = {};

    $this->{_e}->{area} = $o{area};
    $this->{_e}->{name} = $o{name};
    $this->{_e}->{hidden} = 0;
    $this->{_e}->{ievents} = {};
    $this->{_e}->{eevents} = {};
    $this->{_e}->{aevents} = {};
    $this->{_e}->{lastticks} = 0;
    $this->{_e}->{lastevent} = 0;

    $this->SUPER::new(@_);

    return $this;
}

sub area {
    my $this = shift;

    if (@_) {
        my $x = shift @_;
        #logger('setting area to %dx%d', $x->width(), $x->height());
        $this->{_e}->{area} = $x;
        #$this->{_e}->{area} = shift if (@_);
    }
    #logger('returning area %dx%d', $this->{_e}->{area}->width(), $this->{_e}->{area}->height());
    return $this->{_e}->{area};
}

sub on_interior_event {
    my $this = shift;
    my %o = @_;
    my $eventtype = $o{event};
    my $sub = $o{code};

    $this->{_e}->{ievents}->{$eventtype} = $sub;
}

sub on_exterior_event {
    my $this = shift;
    my %o = @_;
    my $eventtype = $o{event};
    my $sub = $o{code};

    $this->{_e}->{eevents}->{$eventtype} = $sub;
}

sub on_event {
    my $this = shift;
    my %o = @_;
    my $eventtype = $o{event};
    my $sub = $o{code};

    $this->{_e}->{aevents}->{$eventtype} = $sub;
}

sub _collided {
    my $this = shift;
    my %o = @_;
    my $hitx = $o{x};
    my $hity = $o{y};
    
    my $area = $this->area();
    if (!$area) {
        logger('%s doesn\'t have an area', $this->name());
    }
    return 0 if (!$area);

    my $left = $area->x();
    my $right = $left + $area->width;

    my $top = $area->y();
    my $bottom = $top + $area->height;

    if ($left < $hitx && $hitx <= $right) {
        if ($top < $hity && $hity <= $bottom) {
            #print "inside $this, returning [ ".($hitx-$left).",".($hity-$top)."]\n";
            return [$hitx - $left, $hity - $top];
        }
    }
    return 0;
}

sub should_ignore_event {
    my $this = shift;
    my %o = @_;
    my $event = $o{event};
    my $ticks = $o{ticks};

    return 1 if (!$this->visible());
    my $type = $event->type();

    my $ret = 0;
    my $diff = $ticks - $this->{_e}->{lastticks};
    if ($diff < 40 &&
        (($this->{_e}->{lastevent} == SDL::SDL_MOUSEBUTTONDOWN && $type == SDL::SDL_MOUSEBUTTONUP) ||
         ($this->{_e}->{lastevent} == SDL::SDL_MOUSEBUTTONUP && $type == SDL::SDL_MOUSEBUTTONDOWN))
       ) {
        my $typestr;
        if ($this->{_e}->{lastevent} == SDL::SDL_MOUSEBUTTONDOWN) {
            $typestr = "MOUSEDOWN";
        } elsif ($this->{_e}->{lastevent} == SDL::SDL_MOUSEBUTTONUP) {
            $typestr = "MOUSEUP";
        } else {
            $typestr = "other";
        }
        logger('ignoring event %s, too fast', $typestr);
        $ret = 1; # event received too fast, ignore it
    }
    $this->{_e}->{lastticks} = $ticks;
    $this->{_e}->{lastevent} = $type;
    return $ret;
}

sub receive_event {
    my $this = shift;
    my %o = @_;
    my $event = $o{event};
    my $ticks = $o{ticks};

    return 0 if ($this->should_ignore_event(event=>$event, ticks=>$ticks));
    my $type = $event->type();

    my($inside, $where, $dosub);
    if ($dosub = $this->{_e}->{aevents}->{$type}) {
        $where = 'any';
    } else {
        $inside = $this->_collided(x=>$event->motion_x(), y=>$event->motion_y());
        $dosub = $inside ? $this->{_e}->{ievents}->{$type} : $this->{_e}->{eevents}->{$type};
        $where = $inside ? 'interior' : 'exterior';
    }
    if (defined($dosub)) {
        eval {
            &$dosub($this, $event, $inside);
        };
        warn($@) if ($@);
        return 1;
    } else {
        eval {
            if ($type == SDL_MOUSEBUTTONDOWN) {
                if ($where eq 'interior') {
                    $this->onMouseDown_interior(event=>$event);
                } else {
                    $this->onMouseDown_exterior(event=>$event);
                }
            } elsif ($type == SDL_MOUSEBUTTONUP) {
                if ($where eq 'interior') {
                    $this->onMouseUp_interior(event=>$event);
                } else {
                    $this->onMouseUp_exterior(event=>$event);
                }
            }
        };
        warn ($@) if ($@);
        return 1;
    }
    return 0;
}

sub visible {
    my $this = shift;

    my $prev = $this->SUPER::visible();
    return $prev if (!@_);
    my $now = $this->SUPER::visible(@_);
    if ($now != $prev) {
        if ($now) {
            $this->onShow();
        } else {
            $this->onHide();
        }
    }
    return $now;
}

sub onMouseDown_interior { return 0; }
sub onMouseDown_exterior { return 0; }
sub onMouseUp_interior { return 0; }
sub onMouseUp_exterior { return 0; }
sub onHide { return 0; }
sub onShow { return 0; }

1;

