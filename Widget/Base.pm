#!/usr/bin/perl

package Widget::Base;

use strict;
use warnings;

use Carp qw(cluck);

use Thundaural::Logger qw(logger);

sub new {
    my $this = shift;
    my %o = @_;
    my $class = ref($this) || $this;
    $this = {} if (ref($this) eq '');
    bless $this, $class;

    $this->{_w} = {};
    $this->{_w}->{name} = $o{name};
    $this->{_w}->{themehandler} = undef;
    $this->{_w}->{visible} = 1;

    $this->widget_initialize(@_);

    return $this;
}

sub start {
    return 0;
}

sub stop { 
    return 0;
}

sub widget_initialize {
    my $this = shift;
    return 0;
}

sub theme {
    my $this = shift;
    my $h = shift;

    if ($h) {
        $this->{_w}->{themehandler} = $h;
        return 1;
    }
    return $this->{_w}->{themehandler};
}

sub container {
    my $this = shift;
    return $this->theme(@_);
}

sub name {
    my $this = shift;
    my $name = shift;

    $this->{_w}->{name} = shift if (@_);
    return $this->{_w}->{name};
}

sub draw {
    my $this = shift;
    die(ref($this)." didn't override Widget::Base::draw\n");
    return 0;
}

sub redraw {
    my $this = shift;
    die(ref($this)." didn't override Widget::Base::redraw\n");
    return 0;
}

sub should_draw {
    my $this = shift;
    return !$this->hidden();
}

sub request_blit {
    my $this = shift;
    my %o = @_;
    if (!$o{name}) {
        $o{name} = $this->{_w}->{name};
    }

    my $wh = $this->{_w}->{themehandler};
    return $wh->request_blit(%o);
}

sub visible {
    my $this = shift;

    if (@_) {
        my $newvisible = shift;
        my $curvisible = $this->{_w}->{visible};
        $this->{_w}->{visible} = $newvisible;
        if ($curvisible != $newvisible) {
            if ($newvisible) {
                $this->redraw();
            } else {
                $this->erase();
            }
        }
    }
    return $this->{_w}->{visible};
}

sub area {
    return undef; # child should override, see Widget::EventReceiver
}

sub erase {
    my $this = shift;

    my $t = $this->theme();
    if (my $a = $this->area()) {
        $t->erase_area($a);
    }
}

sub bgcolor {
    my $this = shift;
    $this->{_w}->{bgcolor} = shift if (@_);
    return $this->{_w}->{bgcolor};
}

1;

