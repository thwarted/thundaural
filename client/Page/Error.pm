#!/usr/bin/perl

package Page::Error;

use strict;
use warnings;

use Carp;

use Logger;

use strict;
use warnings;

use Logger;

use SDL;
use SDL::Constants;
use SDL::Surface;
use SDL::App;
use SDL::Event;
use SDL::Color;
use SDL::Timer;
use SDL::Font;
use SDL::TTFont;
use SDL::Tool::Graphic;
use SDL::Cursor;

use Page;
use Button;

our @ISA = qw( Page );

my $errormsgfont = './fonts/Vera.ttf';
my $errormsgfontsize = 20;

sub new {
	my $proto = shift;
	my %o = @_;

	my $class = ref($proto) || $proto;
	my $this = $class->SUPER::new(@_);
	bless ($this, $class);

	$this->{-canvas} = $o{-canvas};
	croak("-canvas option is not of class SDL::Surface")
		if (!ref($this->{-canvas}) && !$this->{-canvas}->isa('SDL::Surface'));

	$this->{-font} = new SDL::TTFont(
				-name=>$errormsgfont,
				-size=>$errormsgfontsize,
				-bg=>new SDL::Color(-r=>140,-g=>140,-b=>140),
				-fg=>new SDL::Color(-r=>0,-g=>0,-b=>0)
			);

	$this->_make();

	return $this;
}

sub _make() {
	my $this = shift;

	my $buttonerror = new Button(
			-name=>'buttonerror',
			-canvas=>$this->{-canvas},
			-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
			-mask=>new SDL::Rect(-width=>500,-height=>500, -x=>(($this->{-canvas}->width())-500)/2, -y=>(($this->{-canvas}->height())-500)/2)
		);
	$this->add_widget('00-buttonerror', $buttonerror);
}

sub update {
	my $this = shift;
	my $errormsg = shift;

	my($p, $f, $l) = caller;

	my $x = new SDL::Surface(-width=>500, -height=>500);
	$x->display_format();
	$x->fill(0, new SDL::Color(-r=>140,-g=>140,-b=>140));
	my $fh = $this->{-font}->height;
	my @lines = split(/\n/, $errormsg);
	my $lpos = $fh;
	foreach my $l (@lines) {
		my $fw = $this->{-font}->width($l);
		if ($fw) {
			$this->{-font}->print($x, ((500-$fw)/2), $lpos, $l);
		}
		$lpos += $fh;
	}
	$this->widget('00-buttonerror')->surface(0, $x);
	$this->widget('00-buttonerror')->frame(0);
}

sub now_viewing {
	&main::clear_screen();
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