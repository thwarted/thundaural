#!/usr/bin/perl

package Widget::Surface;

use strict;
use warnings;

use Carp qw(cluck confess croak);

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::Color;

use Thundaural::Logger qw(logger);

use Widget::EventReceiver;
use base 'Widget::EventReceiver'; # mainly for area

sub new {
    my $this = shift;
    my %o = @_;
    my $class = ref($this) || $this;
    $this = {} if (ref($class) eq '');
    bless $this, $class;

    $this->{_s} = {};
    $this->{_s}->{surface} = $o{surface};
    $this->{_s}->{updateevery} = 5000; # default every 5 seconds
    $this->{_s}->{lastupdate} = 0;

    $this->SUPER::new(@_);

    return $this;
}

sub start {
    my $this = shift;

    $this->{_s}->{lastupdate} = -1;
}

sub should_draw {
    my $this = shift;
    my %o = @_;

    return 0 if (!$this->visible());
    return 0 if (!$this->{_s}->{lastupdate});
    return 0 if (!defined($this->{_s}->{updateevery}));
    my $ticks = $o{ticks};
    my $diff = $ticks - $this->{_s}->{lastupdate};
    return ($diff >= $this->{_s}->{updateevery});
}

sub draw {
    my $this = shift;
    my %o = @_;

    if ($this->should_draw(@_)) {
        if ($this->{_s}->{lastupdate}) {
            $o{force} = 1;
        }
        if ($this->draw_info(%o)) {
            if (ref($this->{_s}->{surface})) {
                $this->{_s}->{lastupdate} = $o{ticks};
                $this->erase();
                return $this->request_blit(surface=>$this->{_s}->{surface}, area=>$this->area(), sync=>1, name=>$this->name());
            }
        }
    }
    if ($this->{_s}->{lastupdate} == -1) {
        $this->{_s}->{lastupdate} = $o{ticks};
        $this->erase();
        return $this->request_blit(surface=>$this->{_s}->{surface}, area=>$this->area(), sync=>1, name=>$this->name());
    }

#    if ($this->{_s}->{lastupdate} == -1) {
#        $this->draw_info(@_);
#        if (ref($this->{_s}->{surface})) {
#            $this->{_s}->{lastupdate} = 1;
#            $this->erase();
#            return $this->request_blit(surface=>$this->{_s}->{surface}, area=>$this->area(), sync=>1, name=>$this->name());
#        }
#    }
#    if ($this->should_draw(@_)) {
#        if ($this->draw_info(@_)) {
#            $this->{_s}->{lastupdate} = $o{ticks};
#            if (ref($this->{_s}->{surface})) {
#                $this->erase();
#                return $this->request_blit(surface=>$this->{_s}->{surface}, area=>$this->area(), sync=>1, name=>$this->name());
#            }
#        }
#    }
}

sub redraw {
    my $this = shift;

    $this->{_s}->{lastupdate} = -1;
}

sub update_every {
    my $this = shift;

    $this->{_s}->{updateevery} = shift @_ if (@_);
    $this->{_s}->{updateevery} = 1000 if (defined($this->{_s}->{updateevery}) && !$this->{_s}->{updateevery});
    return $this->{_s}->{updateevery};
}

sub surface {
    my $this = shift;

    if (@_) {
        $this->{_s}->{surface} = shift @_;
    }
    return $this->{_s}->{surface};
}

sub draw_info {
    # child should override
    return 0;
}

1;

