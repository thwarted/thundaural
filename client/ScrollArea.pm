
package ScrollArea;

# $Header: /home/cvs/thundaural/client/ScrollArea.pm,v 1.3 2004/01/17 23:23:51 jukebox Exp $

use strict;
use SDL::Surface;
use SDL::Rect;
use EventReceiver;

use Logger;

our @ISA = qw( EventReceiver );

sub new {
	my $class = shift;
	my %opts = @_;

	my $this = {};
	bless $this, $class;

	$this->{-name} = $opts{-name};
	$this->{-content} = $opts{-content};
	die "undefined content surface" if (!defined($this->{-content} || ref($this->{-content} ne 'SDL::Surface')));
	$this->{-canvas} = $opts{-canvas};
	die "undefined canvas/drawing surface" if (!defined($this->{-canvas}));
	$this->{-width} = $opts{-width}		|| 300;
	$this->{-height} = $opts{-height}	|| 300;
	$this->{-x} = $opts{-x}			|| 0;
	$this->{-y} = $opts{-y}			|| 0;
	$this->{-scrolluntil} = $opts{-scrolluntil} || $this->{-content}->height;
	# if -scrolluntil is not equal to content's height, we assume content is doubled
	# in height with duplicate content to acheive a continuous scrolling effect
	$this->{-offset} = $opts{-offset}	|| 0;
	$this->{-pagesize} = $opts{-pagesize}	|| $this->{-height};

	$this->{-destrect} = new SDL::Rect(-width => $this->{-width}, -height => $this->{-height});
	$this->{-destrect}->x($this->{-x});
	$this->{-destrect}->y($this->{-y});

	$this->{-windowrect} = new SDL::Rect(-width => $this->{-width}, -height => $this->{-height});
	$this->{-windowrect}->x(0);
	$this->{-windowrect}->y(0);

	$this->{-sync} = 1;

	$this->{-predraw} = undef;

	return $this;
}

sub name {
	my $this = shift;
	return $this->{-name};
}

sub width {
	my $this = shift;
	return $this->{-width};
}

sub height {
	my $this = shift;
	return $this->{-height};
}

sub predraw {
	my $this = shift;
	my $code = shift;
	if (ref($code) eq 'CODE') {
		$this->{-predraw} = $code;
	}
}

sub mask {
	my $this = shift;
	return $this->{-destrect};
}

sub scrolluntil {
	my $this = shift;
	my $until = shift;
	my $x = $this->{-scrolluntil};
	$this->{-scrolluntil} = $until;
	return $x;
}

sub content {
	my $this = shift;
	$this->{-content} = shift;
	$this->{-offset} = 0;
}

sub scrollbypage {
	my $this = shift;
	my $pages = shift;

	my $oldoffset = $this->{-offset};
	my $newoffset = $this->_normalize($oldoffset + ($pages * $this->{-pagesize}));
	if ($oldoffset != $newoffset) {
		#Logger::logger("scrolling by page from $oldoffset to $newoffset");
		$this->_scrollto($oldoffset, $newoffset);
	}
	0;
}

sub scrollbypixels {
	my $this = shift;
	my $amount = shift;

	my $oldoffset = $this->{-offset};
	my $newoffset = $this->_normalize($oldoffset + $amount);
	if ($oldoffset != $newoffset) {
		#Logger::logger("scrolling by pixel from $oldoffset to $newoffset");
		$this->_scrollto($oldoffset, $newoffset);
	}
	0;
}

sub reset {
	my $this = shift;
	$this->{-offset} = 0;
}

sub _scrollto {
	my $this = shift;
	my $oldoffset = shift;
	my $newoffset = shift;

	$this->{-offset} = $newoffset;
	$this->_refocus;
	0;
}

sub _normalize {
	my $this = shift;
	my $offset = shift;

	#Logger::logger("height = ".$this->{-content}->height.", scrolluntil = ".$this->{-scrolluntil});
	if ($this->{-scrolluntil} != $this->{-content}->height) {
		my $realheight = $this->{-content}->height / 2;
		if ($offset <= 0) {
			$offset = $realheight - $offset;
		} elsif ($offset > $realheight) {
			$offset %= $realheight;
		}
	} else {
		$offset = 0 if ($offset < 0);
		if ($offset > $this->{-content}->height - $this->{-height}) {
			$offset = $this->{-content}->height - $this->{-height};
		}
	}
	return $offset;
}

sub dosync {
	my $this = shift;
	my $x = $this->{-sync};
	$this->{-sync} = shift;
	return $x;
}

sub _refocus {
	my $this = shift;

	if (ref($this->{-predraw}) eq 'CODE') {
		&{$this->{-predraw}};
	}
	#Logger::logger("_refocus to ".$this->{-offset}, __PACAKGE__);
	my $canvas = $this->{-canvas};
	$this->{-windowrect}->y( $this->{-offset} );
	$this->{-content}->blit($this->{-windowrect}, $canvas, $this->{-destrect});
	$canvas->sync if ($this->{-sync} && ref($canvas) eq 'SDL::App');
	0;
}

sub draw {
	my $this = shift;
	$this->_refocus;
	0;
}

sub at_top {
	my $this = shift;
	#my($p, $f, $l) = caller;
	#Logger::logger("$f:$l called $this at_top");
	#Logger::logger(sprintf("offset = %s, scrolluntil = %s",$this->{-offset}, $this->{-scrolluntil}));
	return ($this->{-offset} > 0) ? 0 : 1;
}

sub at_bottom {
	my $this = shift;
	#my($p, $f, $l) = caller;
	#Logger::logger("$f:$l called $this at_bottom");
	#Logger::logger(sprintf("offset = %s, scrolluntil = %s",$this->{-offset}, $this->{-scrolluntil}));
	# for looping scroll areas, not really used
	#if ($this->{-scrolluntil} != $this->{-content}->height) {
	#	return ($this->{-offset} > ($this->{-content}->height / 2)) ? 0 : 1;
	#}
	return ($this->{-offset} >= ($this->{-content}->height - $this->{-height} - 1)) ? 1 : 0;
}

sub determine_line {
	my $this = shift;
	my $x = shift;
	my $event = shift;
	my $inside = shift;
	my $linesize = shift;

	my $posx = $event->motion_x();
	my $posy = $event->motion_y();

	my $contentposx = $posx - $this->{-destrect}->x;
	my $contentposy = $posy - $this->{-destrect}->y;

	$contentposy = $this->{-offset} + $contentposy;

	my $line = int(($contentposy / $linesize)+1);
	Logger::logger("hit at $contentposy on line $line");
	return $line;
}

1;

__END__

		# you should never make a scrollable area that has content smaller than
		# it's final dest rect
		# might have to draw in two stages

		# try the whole thing first, if we extend beyond the edge of the content, it won't get drawn
		$this->{-windowrect}->y($this->{-offset});
		$this->{-content}->blit($this->{-windowrect}, $canvas, $this->{-destrect});

		my $bottom = $this->{-offset} + $this->{-windowrect}->height;

		if ($bottom > $this->{-content}->height) {
			$drawn = $bottom - $this->{-content}->height;
			$remainder = $bottom - $drawn;

			my $x = new SDL::Rect(-width => $this->{-width}, -height => $remainder);
			$x->x(0);
			$x->y($remainder);

			$this->{-windowrect}->y($this->{-offset});
			$this->{-content}->blit($this->{-windowrect}, $canvas, $this->{-destrect});
		}

