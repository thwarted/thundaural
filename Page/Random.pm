#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/Page/Random.pm,v 1.4 2004/04/08 05:22:43 jukebox Exp $

package Page::Random;

use strict;
use warnings;

use Carp;

use Logger;

use Data::Dumper;

$Data::Dumper::Indent = 0;
$Data::Dumper::Sortkeys = 1;

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
use ProgressBar;

use POSIX qw(strftime);

our @ISA = qw( Page );

my $xbg = new SDL::Color(-r=>140,-g=>140,-b=>140);

my $buttonfontfile = "./fonts/Vera.ttf";
my $buttonfontsize = 20;
my $buttonfont = new SDL::TTFont(-name=>$buttonfontfile, -size=>$buttonfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $stattextfontfile = "./fonts/Vera.ttf";
my $stattextfontsize = 30;
my $stattextfont = new SDL::TTFont(-name=>$stattextfontfile, -size=>$stattextfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $progressfontfile = "./fonts/Vera.ttf";
my $progressfontsize = 14;
my $progressfont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>new SDL::Color(-r=>140, -g=>140, -b=>140), -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));

my $redrawcount = 0;

my $transparent = new SDL::Color(-r=>5, -g=>3, -b=>2);

sub new {
	my $proto = shift;
	my %o = @_;

	my $class = ref($proto) || $proto;
	my $this = $class->SUPER::new(@_);
	bless ($this, $class);

	# passed in options
	$this->{-server} = $o{-server};
	croak("-server option is not of class ClientCommands")
		if (ref($this->{-server}) ne 'ClientCommands');

	$this->{-canvas} = $o{-canvas};
	croak("-canvas option is not of class SDL::Surface")
		if (!ref($this->{-canvas}) && !$this->{-canvas}->isa('SDL::Surface'));

	$this->{-storagedir} = '/home/storage';

	$this->{-topline} = $this->{-rect}->y();

	$this->{-last} = {};
	$this->{-srect} = new SDL::Rect(-width=>1024-200-10-10, -height=>$this->{-rect}->height()-40, -x=>200+15, -y=>$this->{-rect}->y()+10+16+4);
	$this->{-s} = new SDL::Surface(-width=>$this->{-srect}->width(), -height=>$this->{-srect}->height());
	$this->{-s}->display_format();
	{
		my $x = $this->{-s};
		$x->fill(0, $transparent);
		$x->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
		# this code draws a red border on the outside pixels of the surface
		$x->fill(0, new SDL::Color(-r=>255, -g=>0, -b=>0));
		my $inside = new SDL::Rect(
			-x=>1, -y=>1, -height=>$this->{-srect}->height()-2, -width=>$this->{-srect}->width()-2
		);
		$x->fill($inside, $transparent);
	}

	$this->{-lastlines} = ();

	$this->{-coverartfile} = '';
	$this->{-coverartsurface} = undef;

	$this->_make();

	return $this;
}

# note that we only support one playback/output device right now
sub _make() {
	my $this = shift;

	my $topline = $this->{-rect}->y();

	my $updater = new Button(
			-name=>'000-updater',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>1, -height=>1, -x=>1200, -y=>800) # off the screen
		);
	$updater->on_event($main::E_UPDATESTATUS, sub { if($this->{-appstate}->{current_page} eq 'random') { $this->update(); } } );
	$this->add_widget($updater); # make sure this sorts first

	my @outputs = @{$this->{-server}->devices('play')};
	my $buttonxpos = 10;
	my $buttonypos = $this->{-srect}->y()+10;
	my $firstoutput = shift @outputs; # we only handle one output here!
	foreach my $output ($firstoutput) {
		foreach my $duration (0, 5, 10, 20, 30, 45, 60, 90, 120) {
			my $actionbutton = new Button(
					-name=>"00-random-$output-$duration",
					-canvas=>$this->{-canvas},
					-mask=>new SDL::Rect(-width=>150, -height=>50, -x=>$buttonxpos, -y=>$buttonypos)
				);
			my $x = new SDL::Surface(-width=>150, -height=>50);
			$x->display_format();
			$x->fill(0, new SDL::Color(-r=>140, -g=>140, -b=>140));
			my $m;
			if ($duration) {
				$m = "$duration minutes";
			} else {
				$m = "off";
			}
			my $fh = $buttonfont->height();
			my $fw = $buttonfont->width($m);
			$buttonfont->print($x, ((150-$fw)/2), ((50-$fh)/2), $m);
			$actionbutton->surface('0', $x);
			$this->add_widget($actionbutton);
			$actionbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
						Logger::logger("got button $output for $duration");
						$this->{recently_requested_random_play} = time() + 3;
						$this->{-server}->random_play($duration, $output);
					} );
			$buttonypos += 50 + 10;
		}
		$buttonxpos += 150 + 10;
	}

#		my $coverartbutton = new Button(
#				-name=>"00-coverart-$reader",
#				-canvas=>$this->{-canvas},
#				-mask=>new SDL::Rect(-width=>200, -height=>200, -x=>10, -y=>$topline+10)
#			);
#		$coverartbutton->predraw( sub { &main::draw_background($this->widget("00-coverart-$reader")->mask(), $this->{-canvas}); } );
#		$this->add_widget($coverartbutton);

#		my $progressbar = new ProgressBar(
#			-name=>"99-ripprogress-$reader",
#			-canvas=>$this->{-canvas},
#			-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
#			-fg=>new SDL::Color(-r=>190, -g=>190, -b=>190),
#			-mask=>new SDL::Rect(-width=>$this->{-srect}->width()-20, -height=>16, -x=>$this->{-srect}->x()+10, -y=>$this->{-rect}->y()+10),
#			-labelfont=>$progressfont,
#			-labelcolor=>new SDL::Color(-r=>160, -g=>160, -b=>160)
#		);
#		$this->add_widget($progressbar);
#	}
}

sub now_viewing() {
	my $this = shift;
	$this->SUPER::now_viewing();
	$this->{-last} = {};
	$this->update();
}

sub get_play_until_time {
	my $this = shift;
	my $device = shift;

	if ($this->{recently_requested_random_play} > time()) {
		return $this->{recently_requested_random_play};
	}
	$this->{recently_requested_random_play} = 0;
	return $this->{-server}->will_randomly_play_until($device);
}

sub update {
	my $this = shift;
	my $barcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
	my $blit = 0;

	my $x = $this->{-s};
	my $g = 10;
	my $indent = 200;
	my @outputs = @{$this->{-server}->devices('play')};
	my $firstoutput = shift @outputs;
	foreach my $output ($firstoutput) {
		my $s = $this->{-server}->will_random_play_until($output);
		my $ss = Dumper([$s]);
		if (!exists($this->{-last}->{$output}) || $this->{-last}->{$output} ne $ss) {
			my $m;
			if ($s) {
				$m = "$output will random play until ".localtime($s);
			} else {
				$m = "random play is off";
			}
			my @lines = $this->wrap($stattextfont, $this->{-srect}->width()-20, $this->{-srect}->height()-20, $m);
			$g += $this->print_lines($x, $stattextfont, 10, $g, @lines);
			#$g += 60;
			$this->{-last}->{$output} = $ss;
			$blit = 1;
		}
	}


	if ($blit) {
		&main::draw_background($this->{-rect}, $this->{-canvas});
		$x->blit(0, $this->{-canvas}, $this->{-srect});
		$this->draw();
		if ($this->{-canvas}->isa('SDL::App')) {
			$this->{-canvas}->sync();
		}
	}
	0;
}

sub print_lines {
	my $this = shift;
	my $surface = shift;
	my $font = shift;
	my $x = shift;
	my $y = shift;
	my @lines = @_;

	my $c = 0;
	my $g = 0;
	foreach my $l (@lines) {
		if (!$this->{-lastlines}->[$c] || $l ne $this->{-lastlines}->[$c]) {
			$l =~ s/\t/        /g;
			$surface->fill(new SDL::Rect(-width=>$this->{-srect}->width()-20, -height=>$font->height(), -x=>10, -y=>$y+$g),
				$transparent);
			my $fw = $font->width($l);
			$font->print($surface, (($this->{-srect}->width()-$fw)/2), $y+$g, $l);
			#$font->print($surface, $x, $y+$g, $l);
		}
		$this->{-lastlines}->[$c] = $l;
		$c++;
		$g += $font->height();
	}
	return $g;
}

sub wrap {
	my $this = shift;
	my $font = shift;
	my $pixelwidth = shift;
	my $pixelheight = shift;
	my @lines = @_;
	my @ret = ();

	my $maxlines = int($pixelheight / $font->height());

	while(@lines) {
		my $l1 = shift @lines;
		my $l2 = '';
		while ((my $x = $font->width($l1)) > $pixelwidth) {
			my($lx, $lastword) = $l1 =~ m/^(.+) ([^ ]+)\s*$/;
			$l1 = $lx if ($lx);
			my $space = $l2 ? ' ' : '';
			$l2 = "$lastword$space$l2" if ($lastword);
		}
		unshift(@lines, $l2) if ($l2);
		push(@ret, $l1);
		last if ((scalar @ret) >= $maxlines);
	}
	my $padded = 0;
	while ((scalar @ret) < $maxlines) {
		push(@ret, " ");
		$padded++;
	}
	return @ret;
}

sub sectotime {
	my $this = shift;
	my $sec = shift;
	my $short = shift;

	my $min = int($sec / 60);
	$sec = $sec % 60;
	my $hrs = int($min / 60);
	$min = $min % 60;

	if ($short) {
		my @ret = ();
		push(@ret, $hrs) if ($hrs);
		push(@ret, sprintf("%02d", $min));
		push(@ret, sprintf("%02d", $sec));
		return join(":", @ret);
	} else {
		my @ret = ();
		push(@ret, "$hrs hours") if ($hrs);
		push(@ret, "$min minutes") if ($min);
		push(@ret, "$sec seconds") if ($sec);
		my $last = pop @ret;
		return join(', ', @ret)." and ".$last;
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
