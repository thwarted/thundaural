
package Button;

# $Header: /home/cvs/thundaural/client/Button.pm,v 1.3 2003/12/30 07:00:44 jukebox Exp $

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
        my $proto = shift;
        my %o = @_;

	my $class = ref($proto) || $proto;
	my $this = $class->SUPER::new(@_);
	bless ($this, $class);

	$this->{-name} = $o{-name};
	$this->{-bg} = $o{-bg};
	$this->{-canvas} = $o{-canvas};
	$this->{-mask} = $o{-mask};
	$this->{-sync} = !$o{-nosync};
	$this->{-alpha} = $o{-alpha};
	$this->{-hide} = 0;
	$this->{-predraw} = undef;

	return $this;
}

sub name {
	my $this = shift;
	return $this->{-name};
}

# the surface we appear on
sub canvas {
	my $this = shift;
	my $c = shift;
	$this->{-canvas} = $c;
}

sub background {
	my $this = shift;
	my $c = shift;
	$this->{-bg} = $c;
}

sub predraw {
	my $this = shift;
	my $code = shift;
	if (ref($code) eq 'CODE') {
		$this->{-predraw} = $code;
	}
}


# adds new visual to how this button should look named $frame
sub surface {
	my $this = shift;
	my $frame = shift;
	my $surface = shift;
	return $this->{-surfaces}->{$frame} if (!$surface || ref($surface) ne 'SDL::Surface');

	if (!exists($this->{-surfaces}) || !defined($this->{-surfaces})) {
		$this->{-surfaces} = {};
		$this->{-frame} = $frame;
	}
	my $buttonsize = $this->{-mask};
	my $buttonsizex = $buttonsize->width;
	my $buttonsizey = $buttonsize->height;
	if ($buttonsizex != $surface->width || $buttonsizey != $surface->height) {
		$surface = SDL::Tool::Graphic::zoom(undef, $surface, $buttonsizex / $surface->width, $buttonsizey / $surface->height, 1);
	}
	$this->{-surfaces}->{$frame} = $surface;
	1;
}

sub surface_for_frame {
	my $this = shift;
	my $frame = shift;

	my $x = $this->{-surfaces}->{$frame};
	if (ref($x) eq 'SDL::Surface') {
		return $x;
	}
	Logger::logger("frame $frame for button $this isn't an SDL::Surface");
	return undef;
}

sub toggle {
	my $this = shift;
	my $curframe = $this->{-frame};
	$curframe = int(!$curframe);
	$this->frame($curframe);
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

# sets the frame, so we know which surface to draw ourselves as
sub frame {
	my $this = shift;
	my $frame = shift;
	my $curframe = $this->{-frame};
	if (defined($frame)) {
		$this->{-frame} = $frame;
		$this->{-drawn} = 0;
		#Logger::logger($this->{-name}.": setting frame from $curframe to $frame");
	}
	return $curframe;
}

sub dosync {
	my $this = shift;
	my $x = $this->{-sync};
	$this->{-sync} = shift;
	return $x;
}

sub hide {
	my $this = shift;
	my $h = shift;
	my $x = $this->{-hide};
	$this->{-hide} = int($h);
	return $x;
}

sub receive {
	my $this = shift;
	return if ($this->{-hide});
	$this->SUPER::receive(@_);
}

sub draw {
	my $this = shift;
	my $frame = shift;

	return if ($this->frame eq $frame && $this->{-drawn});
        if (ref($this->{-predraw}) eq 'CODE') {
                &{$this->{-predraw}};
        }
	my $drect = $this->{-mask};
	if (!$this->{-hide}) {
		$this->frame($frame) if (defined($frame));

		$frame = $this->{-frame};
		my $ss = $this->{-surfaces};
		my $surface = $ss->{$frame};
		if ($surface) {
			$surface->blit(0, $this->{-canvas}, $drect);
		}
	}
	if ($this->{-sync}) {
		if (ref($this->{-canvas}) eq 'SDL::App') {
			$this->{-canvas}->update($drect);
			#$this->{-canvas}->sync;
		}
	}
	$this->{-drawn} = $this->{-frame};
}

1;


__END__

	if (0) {
	my $new = new SDL::Surface(-width => $this->{-mask}->width, -height => $this->{-mask}->height, -flags=>SDL::SDL_SRCCOLORKEY);
	$new->display_format();
	$new->set_color_key(SDL::SDL_SRCCOLORKEY, new SDL::Color(-r=>1,-g=>1,-b=>1));
	$new->fill(0, new SDL::Color(-r=>1,-g=>1,-b=>1));
	#if (defined($this->{-alpha})) {
		##$new->set_alpha($this->SDL_SRCALPHA, $this->{-alpha});
		#$new->set_alpha(65536, $this->{-alpha});
	#}
	my $area = new SDL::Rect(-width => $this->{-mask}->width, -height => $this->{-mask}->height, -x=>0, -y=>0);
	if (my $bg = $this->{-bg}) {
		$new->fill($area, $bg);
	}
	$surface->blit(0, $new, $area);
	}
