#!/usr/bin/perl

package Page::Error;

use strict;
use warnings;

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

sub new {
	my $proto = shift;
	my %o = @_;

	my $class = ref($proto) || $proto;
	my $this = $class->SUPER::new(@_);
	bless ($this, $class);

	$this->{-canvas} = $o{-canvas};
	die("canvas is not an SDL::Surface") if (!ref($this->{-canvas}) && !$this->{-canvas}->isa('SDL::Surface'));

	$this->{-font} = new SDL::TTFont(
				-name=>'/usr/share/fonts/msfonts/georgia.ttf',
				-size=>20,
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

sub now_viewing() {
	&main::clear_screen();
}

1;

