#!/usr/bin/perl

package ProgressBar;

# $Header: /home/cvs/thundaural/client/ProgressBar.pm,v 1.4 2004/01/30 05:35:02 jukebox Exp $

use strict;
use SDL;
use SDL::Color;
use SDL::App;
use SDL::Surface;
use SDL::Constants;
use SDL::Surface;
use SDL::Tool::Graphic;
use SDL::Font;
use SDL::TTFont;

use EventReceiver;

our @ISA = qw( EventReceiver );

my $transparent = new SDL::Color(-r=>5, -g=>3, -b=>2);

sub new {
	my $class = shift;
	my $this = {};
	my %opts = @_;

	$this->{-name} = $opts{-name};
	$this->{-sync} = !$opts{-nosync};
	$this->{-canvas} = $opts{-canvas};
	$this->{-bg} = $opts{-bg};
	$this->{-fg} = $opts{-fg} || new SDL::Color(-r=>192,-g=>128,-b=>96);
	$this->{-mask} = $opts{-mask};
	$this->{-amount} = 0;
	$this->{-hide} = 0;
	$this->{-line} = $opts{-line};

	$this->{-label} = $opts{-label};
	$this->{-labelcolor} = $opts{-labelcolor} || new SDL::Color(-r=>0, -g=>0, -b=>0);
	$this->{-labelfont} = $opts{-labelfont};
	if ($this->{-labelfont} && ref($this->{-labelfont}) ne 'SDL::TTFont' && -s $this->{-labelfont} ) {
		$this->{-labelfont} = new SDL::TTFont(-name=>$this->{-labelfont}, -size=>($this->{-mask}->y() - 2), -bg=>$this->{-fg}, -fg=>$this->{-labelcolor});
	}

	bless $this, $class;
	return $this;
}

sub name {
	my $this = shift;
	return $this->{-name};
}

sub pctfull {
	my $this = shift;
	my $pct = shift;

	$this->{-amount} = $pct;
}

sub hide {
	my $this = shift;
	my $h = shift;
	my $x = $this->{-hide};
	$this->{-hide} = $h;
	return $x;
}

sub dosync {
        my $this = shift;
        my $x = $this->{-sync};
        $this->{-sync} = shift;
        return $x;
}

sub mask {
	my $this = shift;
	my $rect = shift;
	if (defined($rect)) {
		die "not SDL::Rect" if (ref($rect) ne 'SDL::Rect');
		$this->{-mask} = $rect;
	}
	$this->{-mask};
}

sub bg {
	my $this = shift;
	my $color = shift;

	my $oldcolor = $this->{-bg};
	if ($color && ref($color) eq 'SDL::Color') {
		$this->{-bg} = $color;
	}
	return $oldcolor;

}

sub fg {
	my $this = shift;
	my $color = shift;

	my $oldcolor = $this->{-fg};
	if ($color && ref($color) eq 'SDL::Color') {
		$this->{-fg} = $color
	}
	return $oldcolor;
}

sub label {
	my $this = shift;
	my $label = shift;

	my $oldlabel = $this->{-label};
	$this->{-label} = $label;
	return $oldlabel;
}

sub predraw {
	my $this = shift;
	my $code = shift;
	if (ref($code) eq 'CODE') {
		$this->{-predraw} = $code;
	}
}


sub draw {
	my $this = shift;

	my $canvas = $this->{-canvas};
	my $drect = $this->{-mask};

	return if (!$drect);
	if (!$this->{-hide}) {
		my $new = new SDL::Surface(-width=>$drect->width, -height =>$drect->height );
		$new->display_format();
		if (ref($this->{-predraw}) eq 'CODE') {
			&{$this->{-predraw}};
		}

		if (my $bg = $this->{-bg}) {
			$new->fill(0, $bg);
		} else {
			$new->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
			$new->fill(0, $transparent);
		}

		if ($this->{-line}) {
			my $linewidth = int($drect->width / 100);
			my $w = int($drect->width * $this->{-amount});
			$w = $drect->width - $linewidth if ($w >= $drect->width);
			$w = 0 if ($w < 0);
			my $area = new SDL::Rect(-width=>$linewidth, -height=>($drect->height), -x=>$w, -y=>0);
			$new->fill($area, $this->{-fg});
		} else {
			my $w = int($drect->width * $this->{-amount});
			$w = ($drect->width) if ($w >= $drect->width);
			$w -= 2; # account for the border
			$w = 0 if ($w < 0);
			my $area = new SDL::Rect(-width=>$w, -height=>($drect->height)-2, -x=>1, -y=>1);
			$new->fill($area, $this->{-fg});
		}

		if ($this->{-label} && ref($this->{-labelfont}) eq 'SDL::TTFont') {
			my $width = $this->{-labelfont}->width($this->{-label});
			$this->{-labelfont}->print($new, ($drect->width - $width) / 2, 0, $this->{-label});
		}

		$new->blit(0, $canvas, $drect);
	}
	if ($this->{-sync}) {
		if (ref($canvas) eq 'SDL::App') {
			$canvas->update($drect);
			#$canvas->sync;
		}
	}
}


1;
