#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/Page/OldIdle.pm,v 1.2 2004/01/04 04:57:19 jukebox Exp $

package Page::OldIdle;

use strict;
use warnings;

use Logger;

use Data::Dumper;

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
#my $nexttfontfile = "./fonts/MarkerFeltThin.ttf";
my $nexttfontfile = "/usr/share/fonts/msfonts/arial.ttf";
my $nexttfontsize = 14;
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

	$this->{-imgsurfaces}->{button_play_depressed} = new SDL::Surface(-name=>"./images/button-play-depressed.png");
	$this->{-imgsurfaces}->{button_play_raised} = new SDL::Surface(-name=>"./images/button-play-raised.png");
	$this->{-imgsurfaces}->{button_pause_depressed} = new SDL::Surface(-name=>"./images/button-pause-depressed.png");
	$this->{-imgsurfaces}->{button_pause_raised} = new SDL::Surface(-name=>"./images/button-pause-raised.png");
	$this->{-imgsurfaces}->{button_skip_depressed} = new SDL::Surface(-name=>'./images/button-skip-depressed.png');
	$this->{-imgsurfaces}->{button_skip_raised} = new SDL::Surface(-name=>'./images/button-skip-raised.png');
	$this->{-imgsurfaces}->{volumemin} = new SDL::Surface(-name=>'./images/volume-min.png');
	$this->{-imgsurfaces}->{volumemax} = new SDL::Surface(-name=>'./images/volume-max.png');

	$this->{-drawsrc} = new SDL::Surface(-width=>$this->{-rect}->width(), -height=>$this->{-rect}->height(), -flags=>SDL::SDL_SRCCOLORKEY); # 768 is more height than we'll end up drawing
	$this->{-drawsrc}->display_format();

	$this->{-topline} = $this->{-rect}->y();

	$this->_make();

	return $this;
}

sub _make() {
	my $this = shift;
	my $bgcolor = new SDL::Color(-r=>160, -g=>160, -b=>190);

	my $updater = new Button(
			-name=>'updater',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>1, -height=>1, -x=>1200, -y=>800) # off the screen
		);
	$updater->on_event($main::E_UPDATESTATUS, sub { if($this->{-appstate}->{current_page} eq 'idle') { $this->update(); } } );
	$this->add_widget('000-updater', $updater);

	my $outputs = $this->{-server}->devices('play');
	foreach my $channel (@$outputs) {
		# note that the skip button's name is sorted near the end (99-)
		# and that its position is relative to $app, even though we are
		# drawing everything else on a sub surface
		# this is because EventReceiver doesn't handle nested controls
		my $skipbutton = new Button(
				-name=>"skipbutton-$channel",
				-canvas=>$this->{-canvas},
				#-bg=>$bgcolor,
				-mask=>new SDL::Rect(-width=>72, -height=>72, -x=>20, -y=>200) # $topline+4+$g)
			);
		$skipbutton->surface('depressed', $this->{-imgsurfaces}->{button_skip_depressed});
		$skipbutton->surface('raised', $this->{-imgsurfaces}->{button_skip_raised});
		$skipbutton->frame('raised');
		$skipbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
				$skipbutton->draw('depressed'); 
				$this->{-server}->skip($channel); 
				$this->queue_widget_frame("99-skip-$channel", 'raised');
			} );

		# note that the pause button's name is sorted near the end (99-)
		# and that its position is relative to $app, even though we are
		# drawing everything else on a sub surface
		# this is because EventReceiver doesn't handle nested controls
		my $pausebutton = new Button(
				-name=>"pausebutton-$channel",
				-canvas=>$this->{-canvas},
				-mask=>new SDL::Rect(-width=>72, -height=>72, -x=>20, -y=>200) # $topline+4+$g)
			);
		$pausebutton->surface('play-depressed', $this->{-imgsurfaces}->{button_play_depressed});
		$pausebutton->surface('play-raised', $this->{-imgsurfaces}->{button_play_raised});
		$pausebutton->surface('pause-depressed', $this->{-imgsurfaces}->{button_pause_depressed});
		$pausebutton->surface('pause-raised', $this->{-imgsurfaces}->{button_pause_raised});
		my $pauseable = $this->{-server}->pauseable($channel);

		$pausebutton->frame($pauseable ? 'pause-raised' : 'play-raised');
		$pausebutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
				my $pauseable = $this->{-server}->pauseable($channel);
				my $f1 = $pauseable ? "pause" : "play";
				my $f2 = $pauseable ? "play" : "pause";
				$pausebutton->draw("$f1-depressed"); 
				Logger::logger("pausing $channel"); 
				$this->{-server}->pause($channel); 
				$this->queue_widget_frame("99-pause-$channel", "$f2-raised");
			} );

		my $volumebar = new ProgressBar(
				-name=>"volume-$channel",
				-canvas=>$this->{-canvas},
				-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
				-fg=>new SDL::Color(-r=>255, -g=>0, -b=>0),
				-labelfont=>$volumefont,
				-line=>1,
				# other values are filled in during page redraw
				);
		$volumebar->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
				my ($vb, $event, $inside) = @_; 
				my $newvol = eval { 
					int($inside->[0] / 4); 
				}; 
				return if(!defined($newvol)); 
				$newvol++ if($newvol > 67); 
				Logger::logger("changing volume on $channel to $newvol"); 
				$this->{-server}->volume($channel, $newvol); 
				$vb->pctfull($newvol / 100); 
				$vb->draw();
			} );
		my $progressbar = new ProgressBar(
				-name=>"progressbar-$channel",
				-canvas=>$this->{-canvas},
				-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
				-fg=>new SDL::Color(-r=>190, -g=>190, -b=>190),
				-mask=>new SDL::Rect(-width=>400, -height=>16, -x=>100, -y=>250), # position will be overriden
				-labelfont=>$progressfont,
				-labelcolor=>new SDL::Color(-r=>160, -g=>160, -b=>160)
			);

		$this->add_widget("99-skip-$channel", $skipbutton);
		$this->add_widget("99-pause-$channel", $pausebutton);
		$this->add_widget("99-volume-$channel", $volumebar);
		$this->add_widget("99-progress-$channel", $progressbar);
	}
}

sub now_viewing() {
	my $this = shift;
	$this->SUPER::now_viewing();
	$this->update();
}

sub update() {
	my $this = shift;
	my $bgcolor = new SDL::Color(-r=>160, -g=>160, -b=>190);
	my $barcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
	my $textupdated = 0;

	my $np = $this->{-server}->playing_on();
	my $outputs = $this->{-server}->devices('play');

	my $x = $this->{-drawsrc};
	$x->fill(0, $bgcolor);
	$x->set_color_key(SDL::SDL_SRCCOLORKEY, $bgcolor);
	my $g = 15; # these are relative to the work canvas
	my $indent = 110;
	$x->fill(new SDL::Rect(-width=>984, -height=>2, -x=>20, -y=>$g), $barcolor);
	$g += 4;
	foreach my $channel (@$outputs) {
		my $track = $np->{$channel};
		my $spicon;
		$spicon = $this->{-imgsurfaces}->{volumemin};
		$spicon->blit(0, $x, new SDL::Rect(-width=>$spicon->width, -height=>$spicon->height, -x=>540-2-$spicon->width, -y=>$g));
		$spicon = $this->{-imgsurfaces}->{volumemax};
		$spicon->blit(0, $x, new SDL::Rect(-width=>$spicon->width, -height=>$spicon->height, -x=>940+2, -y=>$g));

		my $v = $this->{-server}->volume($channel);
		my $vb = $this->widget("99-volume-$channel");
		$vb->mask(new SDL::Rect(-width=>400, -height=>16, -x=>540, -y=>$this->{-topline} +$g+4));
		$v = 0 if (!$v);
		$vb->pctfull($v / 100);
		$vb->label(sprintf("%d%% volume", $v));
		$vb->draw();

		my $gstart = $g;

		if ($track && ref($track) eq 'HASH' && $track->{name}) {
			# reposition skip and pause buttons to where they should be
			$this->widget("99-pause-$channel")->hide(0);
			$this->widget("99-pause-$channel")->mask()->y($this->{-topline}+$g);
			$this->widget("99-pause-$channel")->frame($this->{-server}->pauseable($channel) ? 'pause-raised' : 'play-raised');
			$this->widget("99-skip-$channel")->hide(0);
			$this->widget("99-skip-$channel")->mask()->y($this->{-topline}+$g+74);

			my $y = sprintf("%s-%s", $track->{name}, $track->{performer});
			$tinfofont->print($x, $indent, $g, $channel);
			$g += $tinfofont->height;
			$trackfont->print($x, $indent, $g, $track->{name});
			$g += $trackfont->height;
			$tinfofont->print($x, $indent, $g, $track->{performer});
			$g += $tinfofont->height;

			$g += 4; # top bar padding

			my $trpct = $track->{percentage};
			my $trlen = $track->{length};
			my $trcur = $track->{current};
			my $p = $this->widget("99-progress-$channel");
			if ($p) {
				$p->hide(0);
				$p->mask()->x(20+$indent);
				$p->mask()->y($this->{-topline}+$g);
				if ($trpct && $trlen && $trcur) {
					$p->pctfull($trpct / 100);
					$p->label(sprintf('%.0f%%, %s remaining', $trpct, $this->sectotime($trlen - $trcur, my $short=1)));
				} else {
					$p->pctfull(0);
					$p->label(' ');
				}
				$g += 16; # height of bar
				$g += 4; # bottom padding
				$p->draw();
			}
		} else {
			# reposition skip and pause buttons to where they should be
			$this->widget("99-pause-$channel")->hide(1);
			$this->widget("99-skip-$channel")->hide(1);

			$tinfofont->print($x, $indent, $g, $channel);
			$g += $tinfofont->height;

			$trackfont->print($x, $indent, $g, 'none');
			$g += $trackfont->height;

			my $p = $this->widget("99-progress-$channel");
			$p->hide(1);
		}

		my $c = 0;
		my $ito;
		my $qedtrcks = $this->{-server}->queued_on($channel);
		foreach my $t (@$qedtrcks) {
			last if ($c >= 4);
			if ($c == 0) {
				$g += 4;
				my $prestr = "Coming up: ";
				$ito = $nexttfont->width($prestr);
				$nexttfont->print($x, $indent, $g, $prestr);
			}
			my $trname = $t->{name};
			my $trperf = $t->{performer};
			my $z = sprintf("%s - %s", $trname, $trperf);
			$nexttfont->print($x, $indent+$ito+10, $g, $z);
			$g += $nexttfont->height;
			$c++;
		}
		if ((my $sl = scalar(@$qedtrcks)) > 4) {
			my $z = sprintf(" ... plus %d more", $sl - 4);
			$nexttfont->print($x, $indent+$ito+10, $g, $z);
			$g += $nexttfont->height;

			my $prestr = "Most recently added: ";
			$ito = $nexttfont->width($prestr);
			my $mostrecent = $qedtrcks->[$sl - 1];
			$mostrecfont->print($x, $indent, $g, $prestr);
			$z = sprintf("%s - %s", $mostrecent->{name}, $mostrecent->{performer});
			$mostrecfont->print($x, $indent+$ito+10, $g, $z);
			$g += $mostrecfont->height;
		}
		if ($g < ($gstart + 168)) { $g = $gstart + 168; }
		$x->fill(new SDL::Rect(-width=>984, -height=>2, -x=>20, -y=>$g), $barcolor);
		$g += 4;
	}

	#my $date = sprintf("- %d, %d", time(), $redrawcount++);
	#$tinfofont->print($x, 10, $g, $date);
	#$g += $tinfofont->height;

	&main::draw_background($this->{-rect}, $this->{-canvas});
	$x->blit(0, $this->{-canvas}, $this->{-rect});
	$this->draw();

	if ($this->{-canvas}->isa('SDL::App')) {
		$this->{-canvas}->sync();
	}
	0;
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

__END__
	if (0) {
	my $h = 4; # header line
	foreach my $channel (@$outputs) {
		$h += $tinfofont->height; # output channel label
		$h += $trackfont->height; # track name
		my $track = $np->{$channel};
		if ($track && ref($track) eq 'HASH') {
			$h += $tinfofont->height; # track performer
			$h += $tinfofont->height; # track info
			$h += 24; # progress bar (4 top + 16 height + 4 bottom)
		}
		$h += 8; # padding
		my $t = $this->{-server}->queued_on($channel);
		my $c = scalar @$t;
		if ($c) {
			my $showtracks = $c < 4 ? $c : 4;
			$h += ($showtracks * $nexttfont->height);
			# add up to four tracks
		}
		if ($c > 4) {
			$h += $nexttfont->height; # how many more are queued up
			$h += $nexttfont->height; # most recently added
		}
		$h += 4; # dividing line
	}
	$h += $tinfofont->height; # time line

	#$this->widget('00-playlist')->mask(new SDL::Rect(-width=>984,-height=>$h,-x=>20,-y=>$this->{-rect}->y()));
	}
