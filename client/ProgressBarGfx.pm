

package ProgressBar;

# $Header: /home/cvs/thundaural/client/ProgressBarGfx.pm,v 1.2 2004/04/08 05:22:43 jukebox Exp $

use strict;
																								   
use SDL;
use SDL::Color;
use SDL::App;
use SDL::Surface;
use SDL::Constants;
use SDL::Surface;
use SDL::Tool::Graphic;

use EventReceiver;
                                                                                                                                                                                                   
our @ISA = qw( EventReceiver );

sub new {
	my $class = shift;
	my $this = {};
	my %opts = @_;

	$this->{-name} = $opts{-name};
	$this->{-sync} = !$opts{-nosync};
	$this->{-canvas} = $opts{-canvas};
	$this->{-bg} = $opts{-bg};
	$this->{-mask} = $opts{-mask};
	$this->{-amount} = 0;

	$this->{-imgleft} = new SDL::Surface(-name=>"images/bar_left.png");
	$this->{-imgmid} = new SDL::Surface(-name=>"images/bar_middle.png");
	$this->{-imgright} = new SDL::Surface(-name=>"images/bar_right.png");

	bless $this, $class;
	return $this;
}

sub pctfull {
	my $this = shift;
	my $pct = shift;

	$this->{-amount} = $pct;
}

sub dosync {
        my $this = shift;
        my $x = $this->{-sync};
        $this->{-sync} = shift;
        return $x;
}

sub mask {
	my $this = shift;
	return $this->{-mask};
}

sub draw {
	my $this = shift;

	my $canvas = $this->{-canvas};
	my $drect = $this->{-mask};
																								   
	my $new = new SDL::Surface(-width=>210, -height =>16 );
	$new->display_format();
	if (my $bg = $this->{-bg}) {
		$new->fill(0, $bg);
	}

	my $pos = 0;
	# blit the left side
	my $area = new SDL::Rect(-width =>5, -height =>16, -x=>$pos, -y=>0);
	$this->{-imgleft}->blit(0, $new, $area);
	$pos += 5;

	my $c = $this->{-amount};
	while($c > 0) {
		$area->x($pos);
		$this->{-imgmid}->blit(0, $new, $area);
		$pos += 1;
		$area->x($pos);
		$this->{-imgmid}->blit(0, $new, $area);
		$pos += 1;
		$c--;
	}
																								   
	# blit the right side
	$area->x($pos);
	$this->{-imgright}->blit(0, $new, $area);

	$new->blit(0, $canvas, $drect);
	if ($this->{-sync}) {
		if (ref($canvas) eq 'SDL::App') {
			$canvas->update($drect);
			$canvas->sync;
		}
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
