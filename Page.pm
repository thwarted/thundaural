#!/usr/bin/perl

package Page;

use strict;
use warnings;

use Carp;

use SDL;
use SDL::Constants;
use SDL::Event;

use Logger;

sub new {
	my $class = shift;
	my %o = @_;
	my $this = {};
	bless $this, $class;
	$this->{-widgets} = {};
	$this->{-rect} = $o{-rect};
	$this->{-bgfill} = $o{-bgfill};
	$this->{-appstate} = $o{-appstate};
	$this->{-lastticks} = 0;
	$this->{-lastevent} = 0;
	croak("-bgfill options is not of class SDL::Color")
		if ($this->{-bgfill} && ref($this->{-bgfill}) ne 'SDL::Color');
	return $this;
}

sub add_widget($) {
	my $this = shift;
	my $widget = shift;

	my $name;
	if (ref($widget)) {
		$name = $widget->name();
	} else {
		$name = $widget;
		$widget = shift;
	}
	
	$this->{-widgets}->{$name} = $widget;
}

sub delete_widget($) {
	my $this = shift;
	my $name = shift;

	delete($this->{-widgets}->{$name});
}

sub widget($) {
	my $this = shift;
	my $name = shift;

	warn("$name isn't a defined widget") if (!exists($this->{-widgets}->{$name}));

	return $this->{-widgets}->{$name};
}

sub have_widget($) {
	my $this = shift;
	my $name = shift;

	return exists($this->{-widgets}->{$name});
}

sub widgets() {
	my $this = shift;

	return keys %{$this->{-widgets}};
}

sub hide_widget($) {
	my $this = shift;
	my $name = shift;

	eval {
		$this->{-widgets}->{$name}->hide(1);
	};
}

sub receive {
	my $this = shift;
	my($event, $ticks) = @_;

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

	my @widgets = $this->widgets();
	my $lastpage = $this->{-appstate}->{current_page};
	foreach my $wk (@widgets) {
		# the widgets themselves could edit the object's widget list 
		# so check to make sure the widget exists and catch any errors
		if (exists($this->{-widgets}->{$wk})) {
			eval {
				$this->{-widgets}->{$wk}->receive(@_);
			};
			warn($@) if ($@);
			if ($lastpage ne $this->{-appstate}->{current_page}) {
				Logger::logger("sending events to widgets caused page change");
				last;
			}
		}
	}
}

sub queue_widget_frame {
	my $this = shift;
	my $widget = shift;
	my $frame = shift;
	&main::queue_func_call(sub { $this->{-widgets}->{$widget}->draw($frame); } );
}

# after this method is called, $app->sync should be called to get everything to appear on screen
sub draw {
	my $this = shift;
	my $sync = shift;

	my @widgets = sort $this->widgets();

	if ($this->{-bgfill} && ref($this->{-bgfill}) eq 'SDL::Color') {
        	my $rect = new SDL::Rect(-width=>$this->{-canvas}->width(), -height=>$this->{-canvas}->height(), -x=>0, -y=>0);
        	$this->{-canvas}->fill($this->{-rect}, $this->{-bgfill});
	}

	foreach my $wk (@widgets) {
		next if ($wk =~ m/^xxx/);
		my $widget = $this->{-widgets}->{$wk};
		eval {
			my $x = $widget->dosync(0);
			$widget->draw();
			$widget->dosync($x);
		};
		warn($@) if ($@);
	}
	if ($sync && $this->{-canvas}->isa('SDL::App')) {
		Logger::logger('syncing screen in Page::draw()');
		$this->{-canvas}->sync();
	}
}

sub update() {
	return;
}

sub now_viewing() {
	#&main::clear_screen();
	&main::clear_page_area();
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
