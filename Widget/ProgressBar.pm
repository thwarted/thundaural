#!/usr/bin/perl

package Widget::ProgressBar;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;
use SDL;
use SDL::Rect;
use SDL::Color;
use SDL::Surface;
use SDL::Tool::Graphic;

use Thundaural::Logger qw(logger);

use Widget::EventReceiver;
use base 'Widget::EventReceiver';

my $creating_surf = 0;

sub new {
    my $this = shift;
    my %o = @_;
    my $class = ref($this) || $this;
    $this = {} if (ref($class) eq '');
    bless $this, $class;

    $this->{_pb} = {};
    $this->{_pb}->{label} = '';
    $this->{_pb}->{type} = 'line'; # line or bar
    $this->{_pb}->{orient} = 'h'; # h or v
    $this->{_pb}->{pctfull} = 0;
    $this->{_pb}->{fgcolor} = $o{bgcolor};
    $this->{_pb}->{bgcolor} = $o{fgcolor};
    $this->{_pb}->{font} = $o{font};
    $this->SUPER::new(@_);

    return $this;
}

sub start {
    my $this = shift;

    die(sprintf('%s does not have a bgcolor or fgcolor', $this->name())) 
        if (!$this->{_pb}->{bgcolor} || !$this->{_pb}->{fgcolor});

    my $area = $this->area();
    if ($this->{_pb}->{font} && ref($this->{_pb}->{font}) ne 'SDL::TTFont' && -s $this->{_pb}->{font}) {
        $this->{_pb}->{font} = new SDL::TTFont(-name=>$this->{_pb}->{font}, -size=>($area->height()-2),
                                    -bg=>$this->{_pb}->{bgcolor}, -fg=>$this->{_pb}->{fgcolor});
    }
    #$this->{_pb}->{font}->text_blended(); # slow, default is shaded
    $this->_create_surf();
    $this->{_pb}->{changed} = 1;
    return 0;
}

sub bgcolor {
    my $this = shift;

    $this->{_pb}->{bgcolor} = shift @_ if (@_);
    return $this->{_pb}->{bgcolor};
}

sub fgcolor {
    my $this = shift;

    $this->{_pb}->{fgcolor} = shift @_ if (@_);
    return $this->{_pb}->{fgcolor};
}

sub orientation {
    my $this = shift;

    $this->{_pb}->{orient} = shift @_ if (@_);
    return $this->{_pb}->{orient};
}

sub font {
    my $this = shift;

    $this->{_pb}->{font} = shift @_ if (@_);
    return $this->{_pb}->{font};
}

sub type {
    my $this = shift;

    $this->{_pb}->{type} = shift @_ if (@_);
    return $this->{_pb}->{type};
}

sub area {
    my $this = shift;

    my $x = $this->SUPER::area(@_);
    # avoid recursion, although this should never happen if we don't pass args below
    $this->_create_surf() if (@_ && !$creating_surf); 
    return $x;
}

sub _create_surf {
    my $this = shift;

    $creating_surf = 1;
    my $area = $this->area(); # here, don't pass args, avoid infinite recursion
    $creating_surf = 0;
    my $surf = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>32);
    $this->{_pb}->{surf} = $surf;
    return 0;
}

sub percent_full {
    my $this = shift;
    # pass a fraction between 0 and 1

    my $x = $this->{_pb}->{pctfull};
    if (@_) {
        $this->{_pb}->{pctfull} = shift @_;
        $this->{_pb}->{changed} = 1;
    }
    return $x;
}

sub label {
    my $this = shift;

    my $oldlabel = $this->{_pb}->{label};
    if (@_) {
        $this->{_pb}->{label} = shift @_;
        $this->{_pb}->{changed} = 1;
    }
    return $oldlabel;
}

sub line_thickness {
    my $this = shift;

    my $area = $this->area();
    if ($this->{_pb}->{orient} eq 'h') {
        return int($area->width() / 100);
    } else {
        return int($area->height() / 100);
    }
}

sub draw {
    my $this = shift;
    my %o = @_;
    my $ticks = $o{ticks};

    if (my $sd = $this->should_draw(@_)) {
        my $area = $this->area();
        my $o = $this->{_pb};
        $o->{surf}->fill(0, $o->{bgcolor});
        my $fillrect;
        if ($o->{type} eq 'line') {
            # line style
            if ($o->{orient} eq 'h') {
                # horizontially oriented
                my $linethick = $this->line_thickness();
                my $pos = int($area->width() * $o->{pctfull});
                $pos = $area->width() - $linethick if ($pos >= $area->width());
                $pos = 0 if ($pos < 0);
                $fillrect = new SDL::Rect(-width=>$linethick, -height=>$area->height(), -x=>$pos, -y=>0);
            } else {
                # vertically oriented
                my $linethick = $this->line_thickness();
                my $pos = int($area->height() * $o->{pctfull});
                $pos = $area->height() - $linethick if ($pos >= $area->height());
                $pos = 0 if ($pos < 0);
                $fillrect = new SDL::Rect(-width=>$area->width(), -height=>$linethick, -x=>0, -y=>$pos);
            }
        } else {
            # bar style
            if ($o->{orient} eq 'h') {
                # horizontially oriented
                my $pos = int($area->width() * $o->{pctfull});
                $pos = $area->width() if ($pos > $area->width());
                $pos -= 2; # account for the border
                $pos = 0 if ($pos < 0);
                $fillrect = new SDL::Rect(-width=>$pos, -height=>($area->height()-2), -x=>1, -y=>1);
            } else {
                # vertically oriented
                my $pos = int($area->height() * $o->{pctfull});
                $pos = $area->height() if ($pos > $area->height());
                $pos -= 2; # account for the border
                $pos = 0 if ($pos < 0);
                $fillrect = new SDL::Rect(-width=>$area->width(), -height=>$pos, -x=>1, -y=>1);
            }
        }
        $o->{surf}->fill($fillrect, $o->{fgcolor});
        if ($o->{label} && ref($o->{font}) eq 'SDL::TTFont') {
            my $w = $o->{font}->width($o->{label});
            my $x = ($area->width() - $w) / 2;
            $o->{font}->print($o->{surf}, $x, 0, $o->{label});
        }
        $this->{_pb}->{changed} = 0;
        return $this->request_blit(surface=>$o->{surf}, area=>$area, sync=>1, name=>'progbar');
    }
    return 0;
}

sub should_draw {
    my $this = shift;

    return 1 if ($this->visible() && $this->{_pb}->{changed});
    return 0;
}

sub redraw {
    my $this = shift;

    $this->{_pb}->{changed} = 1;
}

sub onMouseUp_interior {
    my $this = shift;
    my %o = @_;
    my $event = $o{event};

    my $pct;
    my $area = $this->area();
    if ($this->{_pb}->{orient} eq 'h') {
        $pct = ($event->motion_x() - $area->x()) / $area->width();
    } else {
        $pct = ($event->motion_y() - $area->y()) / $area->height();
    }
    $this->onClick(percentage=>$pct);
}

sub onClick {
    # child should override
    return 0;
}

1;

