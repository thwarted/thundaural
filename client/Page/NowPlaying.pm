#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/Page/NowPlaying.pm,v 1.5 2003/12/30 07:01:19 jukebox Exp $

package Page::NowPlaying;

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

my $xbg = new SDL::Color(-r=>160,-g=>160,-b=>160);
my $progressfontfile = "/usr/share/fonts/msfonts/arial.ttf";
#my $progressfontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $progressfontsize = 14;
my $progressfont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>new SDL::Color(-r=>166, -g=>165, -b=>165), -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));
my $volumefontsize = 30;
my $volumefont = new SDL::TTFont(-name=>$progressfontfile, -size=>$volumefontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));

my $transparent = new SDL::Color(-r=>5, -g=>4, -b=>190);

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

	$this->{-layout} = new Layout(-server=>$this->{-server});

	$this->{-storagedir} = '/home/storage';
	
	$this->{-imgsurfaces}->{button_play_depressed} = new SDL::Surface(-name=>"./images/button-play-depressed.png");
	$this->{-imgsurfaces}->{button_play_raised} = new SDL::Surface(-name=>"./images/button-play-raised.png");
	$this->{-imgsurfaces}->{button_pause_depressed} = new SDL::Surface(-name=>"./images/button-pause-depressed.png");
	$this->{-imgsurfaces}->{button_pause_raised} = new SDL::Surface(-name=>"./images/button-pause-raised.png");
	$this->{-imgsurfaces}->{button_skip_depressed} = new SDL::Surface(-name=>'./images/button-skip-depressed.png');
	$this->{-imgsurfaces}->{button_skip_raised} = new SDL::Surface(-name=>'./images/button-skip-raised.png');
	$this->{-imgsurfaces}->{volumemin} = new SDL::Surface(-name=>'./images/volume-min.png');
	$this->{-imgsurfaces}->{volumemax} = new SDL::Surface(-name=>'./images/volume-max.png');
	$this->{-imgsurfaces}->{restart} = new SDL::Surface(-name=>'./images/no.png');

	$this->{-s} = {};
	$this->{-topline} = $this->{-rect}->y();

	$this->{-numsubs} = 0;

	$this->_make();

	return $this;
}

sub now_viewing() {
	my $this = shift;
	$this->SUPER::now_viewing();
	$this->{-last} = {};
	$this->update();
}

sub _make() {
	my $this = shift;

	my $updater = new Button(
			-name=>'000-updater',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>1, -height=>1, -x=>1200, -y=>800) # off the screen
		);
	$updater->on_event($main::E_UPDATESTATUS, sub { if($this->{-appstate}->{current_page} eq 'idle') { $this->update(); } } );
	$this->add_widget($updater);

	my $restart = new Button(
			-name=>'restart',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>17, -height=>17, -x=>0, -y=>($this->{-rect}->y()+$this->{-rect}->height())-21));
	$restart->surface(0, $this->{-imgsurfaces}->{restart});
	$restart->frame(0);
	$restart->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { Logger::logger("exiting"); exit } );
	$this->add_widget($restart);

}

sub update {
	my $this = shift;

	my $outputs = $this->{-layout}->outputs();
	my $changed = 0;
	foreach my $output (@$outputs) {
		my($key, $d);
		# copy it into our own hash, because we modify it, and we don't want to modify the copy that we are passed
		my %po = %{$this->{-server}->playing_on($output)}; 
		my $volume = $po{volume} || 0;
		my $percentage = $po{percentage} || 0;
		my $current = $po{current} || 0;
		# the volume and currently playing song can change, and get updated, independently
		delete($po{volume}); 
		delete($po{percentage});
		delete($po{current});

		delete($po{started});
		delete($po{trackid});
		delete($po{trackref});
		delete($po{type});

		$d = Dumper(\%po);
		$key = "po-$output";
		if (!defined($this->{-last}->{$key}) || ($d ne $this->{-last}->{$key})) {	
			#Logger::logger("$output now playing changed");
			$this->update_output($output, \%po);
			$this->{-last}->{$key} = $d;
			$changed++;
		}

		my $qo = $this->{-server}->queued_on($output);
		$d = Dumper($qo);
		$key = "qo-$output";
		if (!defined($this->{-last}->{$key}) || ($d ne $this->{-last}->{$key})) {	
			#Logger::logger("$output queued changed");
			$this->update_queued($output, $qo);
			$this->{-last}->{$key} = $d;
			$changed++;
		}

		$key = "vol-$output";
		if (!defined($this->{-last}->{$key}) || ($volume ne $this->{-last}->{$key})) {
			#Logger::logger("$output volume changed");
			$this->update_volume($output, $volume);
			$this->{-last}->{$key} = $volume;
			$this->widget("99-volume-$output")->draw() if (!$changed);
		}

		$key = "prog-$output";
		if (!defined($this->{-last}->{$key}) || ($percentage ne $this->{-last}->{$key})) {
			#Logger::logger("$output progress changed");
			$this->update_progress($output, $percentage, $po{length}, $current);
			$this->{-last}->{$key} = $percentage;
			$this->widget("99-progress-$output")->draw() if (!$changed);
		}

	}
	if ($changed) {
		$this->draw();
		$this->{-canvas}->sync() if ($this->{-canvas}->isa('SDL::App'));
	}
}

sub update_output {
	my $this = shift;
	my $output = shift;
	my $po = shift;

	$this->_create_widgets_for_output($output);

	my $b = $this->widget("00-np$output");
	if (!defined($b)) {
		Logger::logger("unable to find button to draw $output now playing information! THIS SHOULD NEVER HAPPEN!");
		return;
	}
	my $drawon = $b->surface_for_frame(0);
	# create a little border
	$drawon->fill(0, new SDL::Color(-r=>0, -g=>0, -b=>0));
	$drawon->fill(new SDL::Rect(-x=>1, -y=>1, -height=>($drawon->height())-2, -width=>($drawon->width())-2), $transparent);

	my $g = 24;
	my $indent = 10;
	foreach my $k (sort keys %{$po}) {
		$progressfont->print($drawon, $indent, $g, sprintf("%s: %s", $k, defined($po->{$k}) ? $po->{$k} : '-'));
		$g += $progressfont->height();
		if ($g > $drawon->height()-$progressfont->height()) {
			$g = 24;
			$indent = ($drawon->width()/2);
		}
	}

	if ($po->{state} eq 'idle') {
		$this->widget("99-skip-$output")->hide(1);
		$this->widget("99-pause-$output")->hide(1);
		$this->widget("99-progress-$output")->hide(1);
	} else {
		my $w = $this->widget("99-pause-$output");
		$w->hide(0);
		$w->frame($this->{-server}->pauseable($output) ? 'pause-raised' : 'play-raised');
		$this->widget("99-skip-$output")->hide(0);
		$this->widget("99-progress-$output")->hide(0);
	}
}

sub update_queued {
	my $this = shift;
	my $output = shift;
	my $qo = shift;

	$this->_create_widgets_for_output($output);

	my $b = $this->widget("00-queued$output");
	if (!defined($b)) {
		Logger::logger("unable to find button to draw $output queued information! THIS SHOULD NEVER HAPPEN!");
		return;
	}
	my $drawon = $b->surface_for_frame(0);
	# create a little border
	$drawon->fill(0, new SDL::Color(-r=>0, -g=>0, -b=>0));
	$drawon->fill(new SDL::Rect(-x=>1, -y=>1, -height=>($drawon->height())-2, -width=>($drawon->width())-2), $transparent);

	my $g = 0;
	foreach my $r (@$qo) {
		$progressfont->print($drawon, 10, $g, sprintf("%s - %s", $r->{performer}, $r->{name}));
		$g += $progressfont->height();
	}
}

sub update_progress {
	my $this = shift;
	my $output = shift;
	my $percentage = shift || 0;
	my $total = shift || 0;
	my $current = shift || 0;

	my $widgetname = "99-progress-$output";
	my $pb = $this->widget($widgetname);
	if (!defined($pb)) {
		Logger::logger("can't find progress bar $widgetname");
		return;
	}
	$pb->pctfull($percentage / 100);
	$pb->label(sprintf('%.0f%%, %s remaining', $percentage, $this->sectotime($total - $current, my $short = 1)));
}

sub update_volume {
	my $this = shift;
	my $output = shift;
	my $volume = shift;

	my $widgetname = "99-volume-$output";
	my $vb = $this->widget($widgetname);
	if (!defined($vb)) {
		Logger::logger("can't find volume bar $widgetname");
		return;
	}
	$volume = 0 if (!$volume);
	$vb->pctfull($volume / 100);
	$vb->label(sprintf("%d%% volume", $volume));
}

sub _create_widgets_for_output {
	my $this = shift;
	my $output = shift;

	return if ($this->have_widget("00-np$output"));

	my $f;
	my $subsize = 300;
	my $top = $this->{-topline}+10+(($subsize+10)*$this->{-numsubs});
	my $w1 = new Button(
			-name=>"00-np$output",
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>($this->{-rect}->width())-20, -height=>$subsize/2, -x=>10, -y=>$top)
		);
	$f = new SDL::Surface(-width=>$this->{-rect}->width()-20, -height=>$subsize/2);
	$f->display_format();
	$f->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
	$w1->surface(0, $f);
	$w1->predraw( sub { &main::draw_background($w1->mask(), $this->{-canvas}); } );
	$w1->dosync(0);
	$this->add_widget($w1);

	my $w2 = new Button(
			-name=>"00-queued$output",
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>($this->{-rect}->width())-20, -height=>($subsize/2)-1, -x=>10, -y=>$top+($subsize/2)+1)
		);
	$f = new SDL::Surface(-width=>$this->{-rect}->width()-20, -height=>($subsize/2)-1);
	$f->display_format();
	$f->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
	$w2->surface(0, $f);
	$w2->predraw( sub { &main::draw_background($w2->mask(), $this->{-canvas}); } );
	$w2->dosync(0);
	$this->add_widget($w2);

	my $progressbar = new ProgressBar(
			-name=>"99-progress-$output",
			-canvas=>$this->{-canvas},
			-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
			-fg=>new SDL::Color(-r=>190, -g=>190, -b=>190),
			-mask=>new SDL::Rect(-width=>400, -height=>16, -x=>14, -y=>$top+4), # position will be overriden
			-labelfont=>$progressfont,
			-labelcolor=>new SDL::Color(-r=>160, -g=>160, -b=>160)
		);
	$this->add_widget($progressbar);

	my $volumebar;
	{
		my $vbwidth = 800;
		my $vbheight = 32;
		$volumebar = new ProgressBar(
				-name=>"99-volume-$output",
				-canvas=>$this->{-canvas},
				-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
				-fg=>new SDL::Color(-r=>255, -g=>0, -b=>0),
				-mask=>new SDL::Rect(-width=>$vbwidth, -height=>$vbheight, -x=>(($this->{-rect}->width()-$vbwidth)/2), -y=>$top+$subsize-$vbheight-4), # position will be overriden
				-labelfont=>$volumefont,
				-line=>1,
			);
	}
	$volumebar->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
			my ($vb, $event, $inside) = @_; 
			my $width;
			eval { $width = $vb->mask()->width(); };
			if ($@) {
				Logger::logger("unable to get width of volume bar: $@");
				return;
			}
			my $newvol = eval { 
				my $x = $width / 100;
				int($inside->[0] / $x); 
			};
			Logger::logger($@) if ($@);
			return if(!defined($newvol)); 
			$newvol++ if($newvol > 67); 
			Logger::logger("changing volume on $output to $newvol"); 
			$this->{-server}->volume($output, $newvol); 
			$vb->pctfull($newvol / 100); 
			$vb->draw();
		} );
	$this->add_widget($volumebar);

	# note that the pause button's name is sorted near the end (99-)
	# and that its position is relative to $app, even though we are
	# drawing everything else on a sub surface
	# this is because EventReceiver doesn't handle nested controls
	my $pausebutton = new Button(
			-name=>"99-pause-$output",
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>72, -height=>72, -x=>1024-72-14, -y=>$top+4) # $topline+4+$g)
		);
	$pausebutton->surface('play-depressed', $this->{-imgsurfaces}->{button_play_depressed});
	$pausebutton->surface('play-raised', $this->{-imgsurfaces}->{button_play_raised});
	$pausebutton->surface('pause-depressed', $this->{-imgsurfaces}->{button_pause_depressed});
	$pausebutton->surface('pause-raised', $this->{-imgsurfaces}->{button_pause_raised});
	$pausebutton->frame($this->{-server}->pauseable($output) ? 'pause-raised' : 'play-raised');
	$pausebutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
			my $pauseable = $this->{-server}->pauseable($output);
			my $f1 = $pauseable ? "pause" : "play";
			my $f2 = $pauseable ? "play" : "pause";
			$pausebutton->draw("$f1-depressed"); 
			Logger::logger("pausing $output"); 
			$this->{-server}->pause($output); 
			$this->queue_widget_frame("99-pause-$output", "$f2-raised");
		} );
	$this->add_widget($pausebutton);

	# note that the skip button's name is sorted near the end (99-)
	# and that its position is relative to $app, even though we are
	# drawing everything else on a sub surface
	# this is because EventReceiver doesn't handle nested controls
	my $skipbutton = new Button(
			-name=>"99-skip-$output",
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>72, -height=>72, -x=>1024-72-14, -y=>$top+4+72+4) # $topline+4+$g)
		);
	$skipbutton->surface('depressed', $this->{-imgsurfaces}->{button_skip_depressed});
	$skipbutton->surface('raised', $this->{-imgsurfaces}->{button_skip_raised});
	$skipbutton->frame('raised');
	$skipbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
			$skipbutton->draw('depressed'); 
			$this->{-server}->skip($output); 
			$this->queue_widget_frame("99-skip-$output", 'raised');
		} );
	$this->add_widget($skipbutton);

	$this->{-numsubs}++;
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

sub update {
	my $this = shift;

	# get current status from server
	my $now = $this->{-server}->volume('main');
	# compare to last set of data
	if (!defined($this->{-last}->{now}) || $now ne $this->{-last}->{now}) {
		# update widget states
		Logger::logger("updating time widget to $now");
		$this->update_time($now);
		$this->{-last}->{now} = $now;
	} else {
		Logger::logger("not updating time widget");
	}
	# draw widgets
	$this->draw();
}
sub update_time {
	my $this = shift;
	my $now = shift;

	my $w = $this->widget('00-time');
	my $s = $w->surface_for_frame(0);

	$s->fill(0, new SDL::Color(-r=>255, -g=>255, -b=>255));
	$s->fill(new SDL::Rect(-x=>1, -y=>1, -height=>48, -width=>148), $transparent);

	my $x = sprintf("%d", defined($now) ? $now : 0);
	$progressfont->print($s, (150-$progressfont->width($x))/2, (50-$progressfont->height) / 2, $x);

	$w->draw();
}
