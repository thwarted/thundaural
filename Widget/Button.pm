#!/usr/bin/perl

package Widget::Button;

use strict;
use warnings;

use Carp qw(cluck confess croak);
use Data::Dumper;
use SDL;
use SDL::Rect;
use SDL::Color;
use SDL::Surface;
use SDL::Tool::Graphic;

use Thundaural::Logger qw(logger);

use Widget::EventReceiver;
use base 'Widget::EventReceiver';

sub new {
    my $this = shift;
    my %o = @_;
    my $class = ref($this) || $this;
    $this = {} if (ref($class) eq '');
    bless $this, $class;

    $this->{_b} = {};
    $this->{_b}->{frames} = [];
    $this->{_b}->{dep_frames} = [];
    $this->{_b}->{lastframe} = -1;
    $this->{_b}->{lasttickdraw} = 0;
    $this->{_b}->{frame} = 0;
    $this->{_b}->{depressed} = 0;
    $this->{_b}->{action} = undef;
    $this->{_b}->{animate} = 0;

    $this->{_b}->{makedepframe} = 0;
    $this->{_b}->{depframemade} = 0;

    $this->SUPER::new(@_);

    return $this;
}

sub start {
    my $this = shift;

    my $numframes = scalar @{$this->{_b}->{frames}};
    my $numdepframes = scalar @{$this->{_b}->{dep_frames}};
    if ($numframes == $numdepframes || ($numframes == 1 && $numdepframes == 0)) {
        return $this->SUPER::start(@_);
    }
    confess("number of frames and number of depressed frames don't match");
}

sub animate {
    my $this = shift;
    if (@_) {
        $this->{_b}->{animate} = shift;
        $this->frame(0) if (!$this->{_b}->{animate});
    }
    return $this->{_b}->{animate};
}

sub clear_frames {
    my $this = shift;
    
    $this->{_b}->{frames} = [];
    $this->{_b}->{dep_frames} = [];
}

sub frame {
    my $this = shift;
    if (@_) {
        my $x = shift;
        $x += 0;
        my $numframes = scalar @{$this->{_b}->{frames}};
        $x %= $numframes if ($numframes);
        $this->{_b}->{frame} = $x;
    }
    return $this->{_b}->{frame};
}

sub lastframe {
    my $this = shift;
    $this->{_b}->{lastframe} = shift if (@_);
    return $this->{_b}->{lastframe};
}

sub widget_initialize {
    my $this = shift;

    my $area = $this->area();
    croak($this->name()."'s area undefined") if (!$area);
    $this->{_b}->{surface} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>24, -flags=>SDL_SRCALPHA);
    $this->{_b}->{surface}->display_format();

    return $this->SUPER::widget_initialize();
}

sub set_frame {
    my $this = shift;
    my %o = @_;
    my $frame = $o{frame};

    $frame = 0 if (!$frame);
    $frame += 0;

    my $surf = $this->_mk_frame(@_);

    $this->{_b}->{frames}->[$frame] = $surf;
    return 1;
}

sub set_depressed_frame {
    my $this = shift;
    my %o = @_;
    my $frame = $o{frame};

    $frame = 0 if (!$frame);
    $frame += 0;

    my $surf = $this->_mk_frame(@_);
    $this->{_b}->{dep_frames}->[$frame] = $surf;
    return 1;
}

sub make_depressed_frame {
    my $this = shift;

    $this->{_b}->{makedepframe} = 1;
    $this->{_b}->{dep_frames} = [];
    $this->{_b}->{depframemade} = 0;
}

sub _mk_dep_frame {
    my $this = shift;

    my $f = $this->{_b}->{frames}->[0];
    return if (!$f);
    $f->rgba();

    my $subsize = 0.9;

    my $dup = SDL::Surface::unserialize($f->serialize());
    $dup = SDL::Tool::Graphic::zoom(undef, $dup, $subsize, $subsize, 1);
    my $new = new SDL::Surface(-depth=>24, -width=>$f->width(), -height=>$f->height());
    $new->display_format();
    $main::theme->draw_background(canvas=>$new, source=>new SDL::Rect($this->area()->tohash()), dest=>0);
    #$new->fill(0, new SDL::Color(-r=>160, -b=>160, -g=>160));
    my $margin = (1.0 - $subsize) / 2;
    $dup->blit(0, $new, new SDL::Rect(-x=>$f->width()*$margin, -y=>$f->height()*$margin, -width=>$f->width()*$subsize, -height=>$f->height()*$subsize));
    $this->set_depressed_frame(frame=>0, surface=>$new);

    $this->{_b}->{makedepframe} = 0;
    $this->{_b}->{depframemade} = 1;

    return 1;
}

sub draw {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};

    if ($this->should_draw(@_)) {
        my $f = $this->frame();
        my $ff;
        my $name = $this->name();
        if ($this->{_b}->{depressed}) {
            $ff = $this->{_b}->{dep_frames}->[$f];
            $name .= " depressed";
        }
        if (!$ff) {
            $ff = $this->{_b}->{frames}->[$f];
            $name = $this->name();
        }
        if ($ff) {
            if ($ticks) {
                $this->{_b}->{lasttickdraw} = $ticks;
            }
            $this->lastframe($f);
            $this->erase();
            return $this->request_blit(surface=>$ff, area=>$this->area(), sync=>1, name=>$name);
        }
    }
    return 0;
}

sub should_draw {
    my $this = shift;
    my %o = @_;

    if ($this->{_b}->{makedepframe} && !$this->{_b}->{depframemade}) {
        if (int(rand(100)) < 5) {
            #logger('making dep frame for %s', $this->name());
            $this->_mk_dep_frame();
        }
    }

    return 0 if (! (scalar @{$this->{_b}->{frames}}));
    return 0 if (!$this->visible());
    return 1 if (defined($o{ticks}) && $o{ticks} == 0 && $this->{_b}->{lasttickdraw} != 0);
    if ($this->{_b}->{animate}) {
        my $diff = $o{ticks} - $this->{_b}->{lasttickdraw};
        if ($diff > $this->{_b}->{animate}) {
            my $f = $this->frame();
            $f++;
            $this->frame($f);
            return 1;
        }
    }
    return 1 if ($this->{_b}->{lasttickdraw} == 0); # redraw was called
    return 0 if ($this->lastframe() == $this->frame());
    return 1;
}

sub redraw {
    my $this = shift;
    $this->{_b}->{lasttickdraw} = 0;
}

sub onMouseDown_interior {
    my $this = shift;

    $this->{_b}->{depressed} = 1;
    $this->redraw();
}

sub onMouseUp_interior {
    my $this = shift;

    my $dep = $this->{_b}->{depressed};

    $this->{_b}->{depressed} = 0;
    $this->redraw();

    if ($dep) {
        $this->onClick();
    }
}

sub onClick { 
    my $this = shift;
    if (my $sub = $this->{_b}->{onClick}) {
        if (ref($sub) eq 'CODE') {
            return &$sub($this);
        }
    }
    return 0; 
}

sub set_onClick {
    my $this = shift;
    $this->{_b}->{onClick} = shift;
}

sub onMouseUp_exterior {
    my $this = shift;

    return if (!$this->{_b}->{depressed});
    $this->{_b}->{depressed} = 0;
    $this->redraw();
}

sub add_frame {
    my $this = shift;

    my $surf = $this->_mk_frame(@_);
    push(@{$this->{_b}->{frames}}, $surf);
    return 1;
}

sub add_depressed_frame {
    my $this = shift;

    my $surf = $this->_mk_frame(@_);
    push(@{$this->{_b}->{dep_frames}}, $surf);
    return 1;
}

sub _mk_frame {
    my $this = shift;
    my %o = @_;
    my $file = $o{file};
    my $resize = $o{resize};
    my $surf = $o{surface};

    croak("only a file or a surface may be passed") if ($file && $surf);

    if ($file) {
        $surf = new SDL::Surface(-name=>$file);
        if ($surf->color_key() == -1 && $surf->alpha() == 255) {
            # it's a GIF image, convert it
            $surf->rgb();
        }
    }
    if ($resize) {
        my $area = $this->area();
        $surf = SDL::Tool::Graphic::zoom(undef,
                    $surf,
                    $area->width() / $surf->width(),
                    $area->height() / $surf->height(),
                    1);
    }

    return $surf;
}

1;

