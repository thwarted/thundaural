#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/Page/Ripping.pm,v 1.9 2004/01/04 04:57:19 jukebox Exp $

package Page::Ripping;

use strict;
use warnings;

use Logger;

use Data::Dumper;

$Data::Dumper::Indent = 0;

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

our @ISA = qw( Page );

my $trackfontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $trackfontsize = 35;
my $tinfofontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $tinfofontsize = 20;
#my $nexttfontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $nexttfontfile = "./fonts/MarkerFeltThin.ttf";
my $nexttfontsize = 30;
my $progressfontfile = "/usr/share/fonts/msfonts/arial.ttf";
my $progressfontsize = 14;
my $xbg = new SDL::Color(-r=>160,-g=>160,-b=>160);
my $trackfont = new SDL::TTFont(-name=>$trackfontfile, -size=>$trackfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $trackfontsmall = new SDL::TTFont(-name=>$trackfontfile, -size=>$trackfontsize*.75, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $tinfofont = new SDL::TTFont(-name=>$tinfofontfile, -size=>$tinfofontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $nexttfont = new SDL::TTFont(-name=>$nexttfontfile, -size=>$nexttfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $mostrecfont = new SDL::TTFont(-name=>$nexttfontfile, -size=>$nexttfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $progressfont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>new SDL::Color(-r=>166, -g=>165, -b=>165), -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));
my $volumefont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));

my $redrawcount = 0;

sub new {
	my $proto = shift;
	my %o = @_;

	my $class = ref($proto) || $proto;
	my $this = $class->SUPER::new(@_);
	bless ($this, $class);

	# passed in options
	$this->{-server} = $o{-server};
	die if (ref($this->{-server}) ne 'ClientCommands');

	$this->{-canvas} = $o{-canvas};
	die("canvas is not an SDL::Surface") if (!ref($this->{-canvas}) && !$this->{-canvas}->isa('SDL::Surface'));

	$this->{-albums} = $o{-albums}; # new Albums(-server=>$this->{-server});
	die("passed argument for -albums not an Album object") if (!ref($this->{-albums}) && !$this->{-albums}->isa('Albums'));

	$this->{-storagedir} = '/home/storage';

	$this->{-topline} = $this->{-rect}->y();

	$this->{-last} = {};
	$this->{-s} = new SDL::Surface(-width=>$this->{-rect}->width(), -height=>$this->{-rect}->height());
	$this->{-s}->display_format();

	$this->{-coverartfile} = '';
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
			my $fw = $tinfofont->width($act);
			my $fh = $tinfofont->height();
			$tinfofont->print($x, ((150-$fw)/2), ((50-$fh)/2), $act);
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
		$coverartbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { Logger::logger("hit coverart"); } );
		$this->add_widget($coverartbutton);
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
	#return ($this->{-server}->status_of($device)->{state} ne 'idle');
}

sub update {
	my $this = shift;
	my $transparent = new SDL::Color(-r=>5, -g=>3, -b=>2);
	my $barcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
	my $blit = 0;

	&main::draw_background($this->{-rect}, $this->{-canvas});

	my $x = $this->{-s};
	my $g = 10;
	my $indent = 400;
	my @readers = @{$this->{-server}->devices('read')};
	my $firstreader = shift @readers;
	foreach my $reader ($firstreader) {
		my $s = $this->{-server}->status_of($reader);
		my $ss = Dumper($s);
		if (!defined($this->{-last}->{$reader}) || $this->{-last}->{$reader} ne $ss) {
			$this->widget("00-ripaction-$reader")->frame($this->busy($reader) ? 'abort' : 'start');
			$x->fill(0, $transparent);
			$x->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
			my $vx = $s->{volume};
			if (defined($vx) && length($vx) > 15) {
				my $h = int(length($vx)/2);
				($s->{volume1}, $s->{volume2}) = $vx =~ m/^(.{$h})(.*)$/;
				delete $s->{volume};
			}
			foreach my $k (sort keys %$s) {
				$nexttfont->print($x, $indent, $g, sprintf('%s ', defined($s->{$k}) ? $s->{$k} : ''));
				my $width = $nexttfont->width(" $k: ");
				$nexttfont->print($x, $indent-$width, $g, sprintf(' %s: ', $k));
				$g += $nexttfont->height;
			}

			$g += 60;
			$this->{-last}->{$reader} = $ss;
			$this->find_coverartfile($reader);
			$blit = 1;
		}
	}

	if ($blit) {
		$x->blit(0, $this->{-canvas}, $this->{-rect});
		$this->draw();
		if ($this->{-canvas}->isa('SDL::App')) {
			$this->{-canvas}->sync();
		}
	}
	0;
}

sub find_coverartfile {
	my $this = shift;
	my $reader = shift; 

	if ($this->{-coverartfile} && (-s $this->{-coverartfile})) {
		if (!$this->{-coverartsurface}) {
			eval {
				$this->{-coverartsurface} = new SDL::Surface(-name=>$this->{-coverartfile});
				#$this->{-coverartsurface}->set_alpha(SDL::SDL_SRCALPHA, 128);
				$this->{-coverartsurface}->display_format();
				$this->widget("00-coverart-$reader")->surface(0, $this->{-coverartsurface});
				$this->widget("00-coverart-$reader")->hide(0);
			};
			if ($@) {
				Logger::logger("unable to create surface from ".$this->{-coverartfile}.": $@");
			}
		}
	} else {
		my $sd = $this->{-storagedir};
		my @cas = ();
		if (opendir(DIR, $sd)) {
			@cas = grep { /coverart/ && -f "$sd/$_" } readdir(DIR);
			closedir DIR;
		}
		my $caf = shift @cas;
		if ($caf) {
			$caf = "$sd/$caf";
			if (-s $caf) {
				$this->{-coverartfile} = $caf;
				Logger::logger("using cover art file $caf");
				eval {
					$this->{-coverartsurface} = new SDL::Surface(-name=>$this->{-coverartfile});
					#$this->{-coverartsurface}->set_alpha(SDL::SDL_SRCALPHA, 128);
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
			$this->widget("00-coverart-$reader")->hide(1);
		}
	}
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
		return join(' and ', @ret);
	}
}

1;

