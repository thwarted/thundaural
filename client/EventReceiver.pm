#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/EventReceiver.pm,v 1.4 2004/04/08 05:22:43 jukebox Exp $

package EventReceiver;

use strict;

use Carp;

use SDL;
use SDL::Constants;
use SDL::Surface;
use SDL::App;
use SDL::Event;
use SDL::Rect;

use Logger;

sub new {
	my $class = shift;
	my $this = {};
 	bless $this, $class;
	$this->{-aevents} = {};
	$this->{-ievents} = {};
	$this->{-eevents} = {};
	return $this;
}

sub on_interior_event {
	my $this = shift;
	my $eventtype = shift;
	my $sub = shift;

	$this->{-ievents}->{$eventtype} = $sub;
	1;
}

sub on_exterior_event {
	my $this = shift;
	my $eventtype = shift;
	my $sub = shift;

	$this->{-eevents}->{$eventtype} = $sub;
	1;
}

sub on_event {
	my $this = shift;
	my $eventtype = shift;
	my $sub = shift;

	$this->{-aevents}->{$eventtype} = $sub;
	1;
}


# sub mask must be overridden and return an SDL::Rect

sub _collided {
	my $this = shift;
	my $hitx = shift;
	my $hity = shift;
	
	my $mask;

	eval {
		$mask = $this->mask();
	};
	warn($@) if ($@);
	return if (!$mask);
	die("value returned by EventReceiver::mask is not of class SDL::Rect")
		if (ref($mask) ne 'SDL::Rect');

	my $left = $mask->x;
	my $right = $left + $mask->width;

	my $top = $mask->y;
	my $bottom = $top + $mask->height;

	if ($left < $hitx && $hitx <= $right) {
		if ($top < $hity && $hity <= $bottom) {
			#print "inside $this, returning [ ".($hitx-$left).",".($hity-$top)."]\n";
			return [$hitx - $left, $hity - $top];
			#return 1;
		}
	}
	return 0;
}

sub receive {
	my $this = shift;
	my $event = shift;
	my $ticks = shift;
	my $widgetname = pop @_;

	my $inside;
	my $where;
	my $diff = $ticks - $this->{-lastticks};
	if ($diff < 200 &&
		(($this->{-lastevent} == SDL::SDL_MOUSEBUTTONDOWN && $event->type() == SDL::SDL_MOUSEBUTTONUP) || 
		 ($this->{-lastevent} == SDL::SDL_MOUSEBUTTONUP && $event->type() == SDL::SDL_MOUSEBUTTONDOWN)) 
	   ) {
		#Logger::logger("event ".$event->type()." received too fast by $this, skipping");
		return;
	}
	$this->{-lastticks} = $ticks;
	$this->{-lastevent} = $event->type();

	my $type = $event->type();
	my $dosub;
	if ($dosub = $this->{-aevents}->{$type}) {
		# all set!
		$where = "any";
	} else {
		$inside = $this->_collided($event->motion_x(), $event->motion_y());
		$dosub = $inside ? $this->{-ievents}->{$type} : $this->{-eevents}->{$type};;
		$where = $inside ? "interior" : "exterior";
	}
	if (defined($dosub)) {
		#printf("$this->receive($event) => %d,%d\n", $event->motion_x(), $event->motion_y()) if $event->type() != 4;
		if ($type == 5) {
			$type = "BUTTON_DOWN";
		} elsif ($type == 6) {
			$type = "BUTTON_UP";
		}
		if ($where ne 'any') {
			Logger::logger("%s(%s) got %s event %s", $this->{-name}, $this, $where, $type);
		}
		eval {
			&$dosub($this, $event, $inside);
		};
		warn($@) if ($@);
	}
}

1;

#    Thundaural Jukebox
#    Copyright (C) 2003-2004  Andrew A. Bakun
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
