#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/Page/Ripping.pm,v 1.23 2004/06/07 01:42:41 jukebox Exp $

package Page::Ripping;

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

my $xbg = new SDL::Color(-r=>160,-g=>160,-b=>160);

my $buttonfontfile = "./fonts/Vera.ttf";
my $buttonfontsize = 20;
my $buttonfont = new SDL::TTFont(-name=>$buttonfontfile, -size=>$buttonfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $stattextfontfile = "./fonts/Vera.ttf";
my $stattextfontsize = 30;
my $stattextfont = new SDL::TTFont(-name=>$stattextfontfile, -size=>$stattextfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $progressfontfile = "./fonts/Vera.ttf";
my $progressfontsize = 14;
my $progressfont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>new SDL::Color(-r=>166, -g=>165, -b=>165), -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));

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

	$this->{-tmpdir} = $o{-tmpdir};

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
		#$x->fill(0, new SDL::Color(-r=>255, -g=>0, -b=>0));
		#my $inside = new SDL::Rect(
		#	-x=>1, -y=>1, -height=>$this->{-srect}->height()-2, -width=>$this->{-srect}->width()-2
		#);
		#$x->fill($inside, $transparent);
	}

	$this->{-lastlines} = ();

	$this->{-coverartfile} = '';
	$this->{-coverartkey} = '';
	$this->{-lastcoverartkey} = '';
	$this->{-lastidletime} = 0;
	$this->{-coverartsurface} = undef;

	$this->_make();

	return $this;
}

# note that we only support one reading/ripping device right now
sub _make() {
	my $this = shift;

	my $topline = $this->{-rect}->y();

	my $updater = new Button(
			-name=>'000-updater',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>1, -height=>1, -x=>1200, -y=>800) # off the screen
		);
	$updater->on_event($main::E_UPDATESTATUS, sub { if($this->{-appstate}->{current_page} eq 'ripping') { $this->update(); } } );
	$this->add_widget($updater); # make sure this sorts first

	my @readers = @{$this->{-server}->devices('read')};
	my $firstreader = shift @readers;
	foreach my $reader ($firstreader) {
		my $actionbutton = new Button(
				-name=>"00-ripaction-$reader",
				-canvas=>$this->{-canvas},
				-mask=>new SDL::Rect(-width=>150, -height=>50, -x=>10, -y=>400)
			);
		foreach my $act ('start', 'abort') {
			my $x = new SDL::Surface(-width=>150, -height=>50);
			$x->display_format();
			$x->fill(0, new SDL::Color(-r=>140, -g=>140, -b=>140));
			my $fw = $buttonfont->width($act);
			my $fh = $buttonfont->height();
			$buttonfont->print($x, ((150-$fw)/2), ((50-$fh)/2), $act);
			$actionbutton->surface($act, $x);
		}
		$actionbutton->frame($this->busy($reader) ? 'abort' : 'start');
		$this->add_widget($actionbutton);
		$actionbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
					if ($this->busy($reader)) { 
						$this->{-server}->abort_rip($reader); 
					} else {
						$this->{-server}->rip($reader);
					}
				} );

		my $coverartbutton = new Button(
				-name=>"00-coverart-$reader",
				-canvas=>$this->{-canvas},
				-mask=>new SDL::Rect(-width=>200, -height=>200, -x=>10, -y=>$topline+10)
			);
		$coverartbutton->predraw( sub { &main::draw_background($this->widget("00-coverart-$reader")->mask(), $this->{-canvas}); } );
		$this->add_widget($coverartbutton);

		my $progressbar = new ProgressBar(
			-name=>"99-ripprogress-$reader",
			-canvas=>$this->{-canvas},
			-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
			-fg=>new SDL::Color(-r=>190, -g=>190, -b=>190),
			-mask=>new SDL::Rect(-width=>$this->{-srect}->width()-20, -height=>16, -x=>$this->{-srect}->x()+10, -y=>$this->{-rect}->y()+10),
			-labelfont=>$progressfont,
			-labelcolor=>new SDL::Color(-r=>160, -g=>160, -b=>160)
		);
		$this->add_widget($progressbar);
	}
}

sub now_viewing() {
	my $this = shift;
	$this->SUPER::now_viewing();
	$this->{-last} = {};
	$this->update();
}

sub busy {
	my $this = shift;
	my $device = shift;

	if (!defined($device)) {
		my @readers = @{$this->{-server}->devices('read')};
		$device = shift @readers;
	}

	my $state = $this->{-server}->status_of($device)->{state};
	return (defined($state) && $state ne 'idle');
}

sub update {
	my $this = shift;
	my $barcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
	my $blit = 0;

	my $x = $this->{-s};
	my $g = 10;
	my $indent = 200;
	my @readers = @{$this->{-server}->devices('read')};
	my $firstreader = shift @readers;
	foreach my $reader ($firstreader) {
		my $s = $this->{-server}->status_of($reader);
		#my $s = {'current' => '0','devicename' => 'cdrom','genre' => 'rock','length' => '358','name' => 'Nothing Natural','percentage' => '40.24','performer' => 'Lush','popularity' => '0','rank' => '0','started' => '1073762898','state' => 'ripping','trackid' => '?','trackref' => '1/4','type' => 'read','volume' => 'with error correction'};

		my $ss = Dumper($s);
		if (!exists($this->{-last}->{$reader}) || $this->{-last}->{$reader} ne $ss) {
			$this->widget("00-ripaction-$reader")->frame($this->busy($reader) ? 'abort' : 'start');
			my @lines;
			if ($s->{state} eq 'idle') {
				$this->widget("99-ripprogress-$reader")->hide(1);
				@lines = ("Insert a disc and hit the start button to rip.");
				push(@lines, " ", $s->{volume}, " ") if ($s->{volume});
				@lines = $this->wrap($stattextfont, $this->{-srect}->width()-20, $this->{-srect}->height()-20, @lines);
				$this->{-lastidletime} = time();
			} elsif ($s->{state} eq 'cleanup') {
				@lines = $this->wrap($stattextfont, $this->{-srect}->width()-20, $this->{-srect}->height()-20, "cleaning up");
			} else {
				if (defined($s->{trackref}) && ($s->{trackref} =~ m/\//)) {
					my $x = $s->{performer}; $x =~ s/\W+/_/g;
					$this->{-coverartkey} = sprintf('%s.%d', $x, $this->{-lastidletime});

					my ($ct, $tt) = $s->{trackref} =~ m/(\d+)\/(\d+)/;
					push(@lines, sprintf('Ripping track %d of %d %s', $ct, $tt, $s->{volume}));
					push(@lines, ' ');
					push(@lines, sprintf('%s - %s', $s->{performer}, $s->{name}));
					#push(@lines, sprintf('%s of %s', $this->sectotime($s->{length}), $s->{genre}));
					push(@lines, $this->sectotime($s->{length}));
					push(@lines, " ");
                   			my $ststr = strftime '%H:%M:%S', localtime($s->{started});
					push(@lines, sprintf('started ripping at %s', $ststr));
					#push(@lines, sprintf('%d errors at current sector', $s->{current}));
				} else {
					push(@lines, sprintf('%s ', $s->{volume}));
				}
				@lines = $this->wrap($stattextfont, $this->{-srect}->width()-20, $this->{-srect}->height()-20, @lines);

				if ($s->{percentage}) {
					my $w = $this->widget("99-ripprogress-$reader");
					$w->hide(0);
					$w->pctfull($s->{percentage} / 100);
					# the rank holds the current ripping speed
					$w->label(sprintf('%d%% - speed %.1fx', $s->{percentage}, $s->{rank}));
				}
			}
			$g += $this->print_lines($x, $stattextfont, 10, $g, @lines);

			$g += 60;
			$this->{-last}->{$reader} = $ss;
			$this->find_coverartfile($reader);
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
			$font->print($surface, $x, $y+$g, $l);
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

sub find_coverartfile {
	# bah, we're only supporting one reader device here
	# when we grab the cover art file from the server
	my $this = shift;
	my $reader = shift; 

	my $caf;
	if ($this->{-coverartkey} && $this->{-lastcoverartkey} ne $this->{-coverartkey}) {
		my $tmpfile = sprintf('%s/thundaural-coverart-ripping-%s.jpg', $this->{-tmpdir}, $this->{-coverartkey});
		if (-e $tmpfile)  {
			$caf = $tmpfile;
		} else {
			$caf = $this->{-server}->coverart('ripping', $tmpfile);
		}

		if (defined($caf) && -s $caf) {
			if (!$this->{-coverartsurface} || $this->{-lastcoverartkey} ne $this->{-coverartkey}) {
				$this->{-coverartfile} = $caf;
				eval {
					$this->{-coverartsurface} = new SDL::Surface(-name=>$this->{-coverartfile});
					$this->{-coverartsurface}->display_format();
					$this->widget("00-coverart-$reader")->surface(0, $this->{-coverartsurface});
					$this->widget("00-coverart-$reader")->hide(0);
				};
				if ($@) {
					Logger::logger("unable to create surface from ".$this->{-coverartfile}.": $@");
				}
			}
		} else {
			$this->{-coverartfile} = '';
			$this->{-coverartsurface} = '';
			$this->{-coverartkey} = '';
			$this->widget("00-coverart-$reader")->hide(1);
		}
	}

	$this->{-lastcoverartkey} = $this->{-coverartkey};
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
		push(@ret, sprintf('%d hour%s', $hrs, $hrs != 1 ? 's' : '')) if ($hrs);
		push(@ret, sprintf('%d minute%s', $min, $min != 1 ? 's' : '')) if ($min);
		push(@ret, sprintf('%d second%s', $sec, $sec != 1 ? 's' : '')) if ($sec);
		my $last = pop @ret;
		if (scalar @ret) {
			return join(', ', @ret)." and ".$last;
		} else {
			return $last;
		}
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
