#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/interface.pl,v 1.22 2004/03/29 08:59:56 jukebox Exp $

use strict;
use warnings;

our ($iCon);

# set this to zero if you want the mouse pointer hidden, like
# if you are using a touchscreen
my $show_mouse_cursor = 1;

my $xscreensaver_start = 'xscreensaver-command -activate';

my $WIN_X = 1024;
my $WIN_Y = 768;

my $debug_timers = 0;

use SDL;
#$SDL::DEBUG = 1;
use SDL::Surface;
use SDL::Constants;
use SDL::App;
use SDL::Event;
use SDL::Color;
use SDL::Timer;
use SDL::Font;
use SDL::TTFont;
use SDL::Tool::Graphic;
use SDL::Cursor;

# jukebox related stuff
use ClientCommands;
use Track;
use Albums;
use Album;

# interface widgets
use EventReceiver;
use Button;
use ScrollArea;
use ProgressBar;

# interface screens/pages
use Page::Stats;
use Page::Error;
use Page::Albums;
use Page::Tracks;
use Page::Ripping;
use Page::NowPlaying;
use Page::Random;

# until user-defined events are working in SDL_perl
our $E_CALLFUNCS=SDL::SDLK_BACKSPACE;
our $E_UPDATESTATUS=SDL::SDLK_COLON;
our $E_ANIMATE=SDL::SDLK_AT;

our $app = &setup($WIN_X, $WIN_Y);

my $Albums;
my $menuarea = new SDL::Rect(-width=>$WIN_X, -height=>98, -x=>0, -y=>0);
my $pagearea = new SDL::Rect(-width=>$WIN_X, -height=>$WIN_Y-94, -x=>0, -y=>98);

my $state = {
	current_page=>'idle',
 	last_page=>'',
	ripping_track=>'',
};

my $imgsurfaces = &load_images;

my $pages = {};
my $instance_tmpdir = '';
&setup_theme(@ARGV);

END { my $x = $?; if ($instance_tmpdir && -d $instance_tmpdir) { `/bin/rm -rf $instance_tmpdir`; } $? = $x; }

my $menuwidgets = &make_menu_widgets;

my $callfuncs = [];

my $totalevents = 0;
my $ticks = {};
$ticks->{animate_delay} = 450;
$ticks->{update_delay} = 500;
$ticks->{animate} = 0;
$ticks->{update} = 0;

&mainloop;

sub mainloop {
	my $loops;
	my $event = new SDL::Event;             # create a new event
	EVENTLOOP:
	while(1) {
		if ($state->{last_page} ne $state->{current_page}) {
			$pages->{$state->{current_page}}->now_viewing(); # notify the page it's being viewed
			$pages->{$state->{current_page}}->draw();
			&draw_widgets; # draw menu
			$state->{last_page} = $state->{current_page};
		}

		# note our tricky implementation here.  If, after a pause, we don't see any events
		# then push an event.   On the next iteration, the condition will be false and we'll
		# exit the loop
		while (!$event->poll()) {
			my $now = $app->ticks();
			if (($now - $ticks->{animate}) > $ticks->{animate_delay}) {
				my $e = new SDL::Event;
				$e->settype($E_UPDATESTATUS);
				$e->push();
				$ticks->{animate} = $now;
			}
			if (($now - $ticks->{update}) > $ticks->{update_delay}) {
				my $e = new SDL::Event;
				$e->settype($E_ANIMATE);
				$e->push();
				$ticks->{update} = $now;
			}
			$app->delay(50);
		}
		$totalevents++;
		my $type = $event->type();      # get event type

		if ($type == SDL::SDL_QUIT) { Logger::logger("request quit"); last; }
		if ($type == SDL::SDL_KEYUP) { if ($event->key_name() eq 'q') { Logger::logger("exiting"); last; } }
		if ($type == SDL::SDLK_EQUALS) {
			# filler
			next;
		}

		if ($type == $E_CALLFUNCS) {
			my $funccount = 0;
			while(@$callfuncs) {
				$funccount++;
				my $sub = shift @$callfuncs;
				&$sub;
			}
			#Logger::logger("E_CALLFUNCS: called $funccount subs");
			next;
		}

		if ($debug_timers) {
			if ($type == $E_UPDATESTATUS) {
				Logger::logger("E_UPDATESTATUS event received");
			}

			if ($type == $E_ANIMATE) {
				Logger::logger("E_ANIMATE event received");
			}
		}

		my $lastpage = $state->{current_page};
		foreach my $o (values %{$menuwidgets}) {
			$o->receive($event);
			if ($lastpage ne $state->{current_page}) {
				Logger::logger("current_page changed due to event");
				next EVENTLOOP;
			}
		}

		if (eval { $pages->{$state->{current_page}}->isa('Page'); } ) {
			$pages->{$state->{current_page}}->receive($event, $app->ticks());
		}

	}
}

sub draw_background($$) {
	my $rect = shift;
	my $canvas = shift;
	#my($p, $f, $l) = caller;
	#if ($p ne 'main') { Logger::logger("draw_background called by $p at $f:$l"); }
	$imgsurfaces->{bg}->blit($rect, $canvas, $rect); # srect, dest, drect
}

sub clear_screen() {
	#my($p, $f, $l) = caller;
	#Logger::logger("clear screen called by $p at $f:$l");
	&draw_background(0, $app);
}

sub clear_page_area() {
	&draw_background($pagearea, $app);
}

sub draw_widgets {
	my $drawmenu = shift;

	&draw_background($menuarea, $app);
	foreach my $widgetk (sort keys %{$menuwidgets}) {
		my $widget = $menuwidgets->{$widgetk};
		eval {
			my $x = $widget->dosync(0);
			$widget->draw;
			$widget->dosync($x);
		};
		Logger::logger($@) if ($@);
	}
	$app->sync;
}

sub show_error_message {
	my $errormsg = shift;
	my $cp = $state->{current_page};
	$state->{current_page} = 'error';
	$pages->{$state->{current_page}}->now_viewing(); # notify the page it's being viewed
	$pages->{$state->{current_page}}->update($errormsg);
	$pages->{$state->{current_page}}->draw();
	$app->sync;
	$state->{current_page} = $cp;
	$state->{last_page} = 'error';
}

sub make_menu_widgets {
	my $bgcolor = new SDL::Color(-r=>160, -g=>160, -b=>160);

	my $gotoidle = new Button(
			-name=>'gotoidle',
			-canvas=>$app,
			-bg=>$bgcolor,
			-mask=>new SDL::Rect(-width=>90,-height=>90,-x=>5,-y=>1)
			);
	{
		$gotoidle->predraw( sub { &main::draw_background($gotoidle->mask(), $app); } );
		$gotoidle->surface(0, $imgsurfaces->{'nowplaying-0'});
		$gotoidle->surface(1, $imgsurfaces->{'nowplaying-1'});
		$gotoidle->surface(2, $imgsurfaces->{'nowplaying-2'});
		$gotoidle->surface(3, $imgsurfaces->{'nowplaying-3'});
		$gotoidle->surface(4, $imgsurfaces->{'nowplaying-4'});
		$gotoidle->surface(5, $imgsurfaces->{'nowplaying-5'});
		$gotoidle->surface(6, $imgsurfaces->{'nowplaying-6'});
		$gotoidle->frame(0);
		$gotoidle->on_event($E_ANIMATE, sub { 
					if (!$iCon->player_active()) {
						$gotoidle->draw(0);
						return;
					}
					my $c = $gotoidle->frame(); 
					$c++; 
					$c = 0 if ($c > 6); 
					$gotoidle->draw( $c ); 
				} );
		$gotoidle->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $state->{current_page} = 'idle'; } );
	}

	my $gotoalbums = new Button(
                	-name=>'gotoalbums',
                	-canvas=>$app,
                	-bg=>$bgcolor,
                	-mask=>new SDL::Rect(-width=>90,-height=>90, -x=>160, -y=>2)
                	);
	{
        	$gotoalbums->surface(0, $imgsurfaces->{'goto_albums'});
		$gotoalbums->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $state->{current_page} = 'albums'; } );
	}

	my $gotorandom = new Button(
			-name=>'gotorandom',
			-canvas=>$app,
			-bg=>$bgcolor,
			-mask=>new SDL::Rect(-width=>90, -height=>90, -x=>300, -y=>2)
			);
	{
        	$gotorandom->surface(0, $imgsurfaces->{'randomize'});
		$gotorandom->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $state->{current_page} = 'random'; } );
	}

	my $st = new Button(
			-name=>"stats",
			-canvas=>$app,
			-bg=>$bgcolor,
			-mask=>new SDL::Rect(-width=>90, -height=>90, -x=>820-90-10, -y=>1)
		);
	{
		$st->predraw( sub { &main::draw_background($st->mask(), $app); } );
		$st->surface(0, $imgsurfaces->{'goto_stats'});
		$st->frame(0);
		$st->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $state->{current_page} = 'stats'; } );
	}

	my $gotoripping = new Button(
			-name=>'gotoripping',
			-canvas=>$app,
			-bg=>$bgcolor,
			-mask=>new SDL::Rect(-width=>90, -height=>90, -x=>820, -y=>2)
			);
	{
		$gotoripping->surface('idle', $imgsurfaces->{'ripcdrom-idle'});
		$gotoripping->surface('busy', $imgsurfaces->{'ripcdrom-busy'});
		$gotoripping->frame($pages->{'ripping'}->busy() ? 'busy' : 'idle');
		$gotoripping->predraw( sub { &main::draw_background($gotoripping->mask(), $app); } );
		$gotoripping->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $state->{current_page} = 'ripping'; } );
		$gotoripping->on_event($E_ANIMATE, sub { 
					if ($iCon->reader_active()) {
						$gotoripping->draw( ( time() % 2 ) == 0 ? 'busy' : 'idle'); 
						return;
					}
					$gotoripping->frame('idle');
				} );
	}

	my $screensaver = new Button(
			-name=>'screensaver',
			-canvas=>$app,
			-bg=>$bgcolor,
			-mask=>new SDL::Rect(-width=>48,-height=>48,-x=>1024-50,-y=>2)
			);
	{
		$screensaver->surface(0, $imgsurfaces->{'start_screensaver'});
		$screensaver->frame(0);
		$screensaver->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, \&start_screensaver);
	}

	return {
		'00-gotoidle'=>$gotoidle,
		'00-gotoalbums'=>$gotoalbums,
		'00-gotorandom'=>$gotorandom,
		'00-stats'=>$st,
		'00-gotoripping'=>$gotoripping,
		'00-screensaver'=>$screensaver,
	};
}

sub queue_func_call {
	my $sub = shift;
	push(@$callfuncs, $sub);
	my $e = new SDL::Event;
	$e->settype($E_CALLFUNCS);
	$e->push;
	0;
}

sub eatevents {
	my $e = new SDL::Event;
	my $c = 0;
	while($e->poll()) {
		$e->wait();
		$c++;
		Logger::logger("eating $c event ".$e->type());
	}
}

sub min {
	my($a, $b) = @_;
	my $x = ($a < $b) ? $a : $b;
	return $x;
}

sub setup {
	my ($x, $y) = @_;
	my $app = new SDL::App( -title => 'Thundaural Jukebox',
				-width => $x,
				-height => $y,
				-depth => 24,
			# can't go fullscreen, because then 
			# the touchscreen doesn't work
			# with a hidden mouse pointer
				-full => 0,
				-flags => SDL::SDL_DOUBLEBUF | 
					SDL::SDL_HWSURFACE | 
					SDL::SDL_HWACCEL 
		);
	if (!$$app) {
		die("creation of SDL::App failed.\n");
	}
	if (!$show_mouse_cursor) {
		SDL::Cursor::show(0);
	}
	return $app;
}

sub sectotime {
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

sub start_screensaver {
	$state->{current_page} = 'albums';
	system("$xscreensaver_start > /dev/null 2>/dev/null");
}

sub printmem {
	open(F, "/proc/self/status");
	while (<F>) {
		print if /VmData/;
	}
	close(F);
}

sub AUTOLOAD {
	my $this = shift;

	my($p, $f, $l) = caller;
	our $AUTOLOAD;
	Logger::logger("attempt to call \"$AUTOLOAD\" by $p ($f:$l) THIS IS A BUG SHOULD NEVER HAPPEN!\n");
	0;
}

sub error_msg_idle {
	my $nowticks = SDL::App::ticks();
	while(SDL::App::ticks() - $nowticks < 3000) {
		my $event = new SDL::Event;
		while ($event->poll()) {
			my $type = $event->type();      # get event type
			if ($type == SDL::SDL_QUIT) { Logger::logger("request quit"); exit; }
			if ($type == SDL::SDL_KEYDOWN) { if ($event->key_name() eq 'q') { Logger::logger("exiting"); exit; } }
		}
		SDL::App::delay(0, 50);
	}
}

sub setup_theme {
	my($host, $port);
	while (@_) {
		$a = shift @_;
		if ($a =~ m/^--host/) {
			$host = shift @_;
		}
		if ($a =~ m/^--port/) {
			$port = shift @_;
		}
	}

	$pages->{'error'} = new Page::Error(-canvas=>$app, -rect=>$pagearea, -appstate=>$state),

	$instance_tmpdir = "/tmp/thundaural-client-cache-$$";
	mkdir $instance_tmpdir, 0700;

	$iCon = new ClientCommands(
			-clientlabel=>'TASDL',
			-idlefunc=>\&error_msg_idle,
			-errorfunc=>\&show_error_message, 
			-recoveredfunc=>\&eatevents, 
			-host=>$host, 
			-port=>$port
		);
	$Albums = new Albums(-server=>$iCon, -tmpdir=>$instance_tmpdir);

	my %args = (
		-server=>$iCon, 
		-canvas=>$app, 
		-rect=>$pagearea, 
		-appstate=>$state, 
		-albums=>$Albums,
		-tmpdir=>$instance_tmpdir
	);

	$pages->{'albums'} = new Page::Albums(%args);
	$pages->{'tracks'} = new Page::Tracks(%args);
	$pages->{'idle'} = new Page::NowPlaying(%args);
	$pages->{'stats'} = new Page::Stats(%args);
	$pages->{'ripping'} = new Page::Ripping(%args);
	$pages->{'random'} = new Page::Random(%args);
}

sub load_images {
	my $imgsurfaces;
	          #$imgsurfaces->{'bg'} = new SDL::Surface(-name=>'./images/bgmetal2.png');
	          #$imgsurfaces->{'bg'} = new SDL::Surface(-name=>'./images/1024x768-Big-Cigars-1.png');
	          $imgsurfaces->{'bg'} = new SDL::Surface(-name=>'./images/1024x768-Appropriately-Left-Handed-1.png');
	          #$imgsurfaces->{'bg'} = new SDL::Surface(-name=>'./images/1024x768-No-Purchase-Necessary-3.png');
	          #$imgsurfaces->{'bg'} = new SDL::Surface(-name=>'./images/1024x768-Dinner-With-Anna-3.png');

               #$imgsurfaces->{speaker} = new SDL::Surface(-name=>'./images/speaker.png');
     $imgsurfaces->{'goto_nowplaying'} = new SDL::Surface(-name=>"./images/goto-nowplaying.png");
         $imgsurfaces->{'goto_albums'} = new SDL::Surface(-name=>'./images/goto-albums.png');
          $imgsurfaces->{'goto_stats'} = new SDL::Surface(-name=>'./images/goto-stats.png');
   $imgsurfaces->{'start_screensaver'} = new SDL::Surface(-name=>"./images/start-screensaver03.png");
       $imgsurfaces->{'ripcdrom-busy'} = new SDL::Surface(-name=>'./images/ripcdrom-busy.png');
       $imgsurfaces->{'ripcdrom-idle'} = new SDL::Surface(-name=>'./images/ripcdrom-idle.png');

           $imgsurfaces->{'randomize'} = new SDL::Surface(-name=>'./images/randomize.png');

        $imgsurfaces->{'nowplaying-0'} = new SDL::Surface(-name=>'./images/nowplaying-speaker0.png');
        $imgsurfaces->{'nowplaying-1'} = new SDL::Surface(-name=>'./images/nowplaying-speaker1.png');
        $imgsurfaces->{'nowplaying-2'} = new SDL::Surface(-name=>'./images/nowplaying-speaker2.png');
        $imgsurfaces->{'nowplaying-3'} = new SDL::Surface(-name=>'./images/nowplaying-speaker3.png');
        $imgsurfaces->{'nowplaying-4'} = new SDL::Surface(-name=>'./images/nowplaying-speaker4.png');
        $imgsurfaces->{'nowplaying-5'} = new SDL::Surface(-name=>'./images/nowplaying-speaker5.png');
        $imgsurfaces->{'nowplaying-6'} = new SDL::Surface(-name=>'./images/nowplaying-speaker6.png');
	return $imgsurfaces;
}

1;

__END__ 

#my $debugfontfile = "/usr/share/fonts/msfonts/arialbd.ttf";
#my $debugfont = new SDL::TTFont(-name=>$debugfontfile, -size=>13, -bg=>new SDL::Color(-r=>255,-g=>255,-b=>255), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
#sub draw_debug_line {
#	my $event = shift;
#	my $x = new SDL::Rect(-width=>1024, -height=>16, -x=>0, -y=>0);
#	$app->fill($x, new SDL::Color(-r=>255,-g=>255,-b=>255));
#	$debugfont->print(
#			$app,
#			1,
#			0,
#		sprintf("event type %d received at %d location %dx%d", $event->type(), $app->ticks(), $event->motion_x(), $event->motion_y())
#		);
#}
#
#our $E_SHOWALBUMS=SDL::SDLK_QUOTE;
#our $E_SHOWTRACKS=SDL::SDLK_QUOTEDBL;
#our $E_SHOWIDLE=SDL::SDLK_SEMICOLON;
#our $E_SHOWERROR=SDL::SDLK_HASH;
#sub changepage {
#	my $page = shift;
#	my $e = new SDL::Event;
#	if ($page eq 'albums') {
#		$e->settype($E_SHOWALBUMS);
#	} elsif ($page eq 'tracks') {
#		$e->settype($E_SHOWTRACKS);
#	} else {
#		$e->settype($E_SHOWIDLE);
#	}
#	my $x = $e->push;
#}

#    $imgsurfaces->{button_next_raised} = new SDL::Surface(-name=>'./images/button-next-raised.gif');
# $imgsurfaces->{button_next_depressed} = new SDL::Surface(-name=>'./images/button-next-depressed.gif');
#    $imgsurfaces->{button_back_raised} = new SDL::Surface(-name=>'./images/button-back-raised.gif');
# $imgsurfaces->{button_back_depressed} = new SDL::Surface(-name=>'./images/button-back-depressed.gif');
# $imgsurfaces->{button_play_depressed} = new SDL::Surface(-name=>"./images/button-play-depressed.png");
#    $imgsurfaces->{button_play_raised} = new SDL::Surface(-name=>"./images/button-play-raised.png");
#$imgsurfaces->{button_pause_depressed} = new SDL::Surface(-name=>"./images/button-pause-depressed.png");
#   $imgsurfaces->{button_pause_raised} = new SDL::Surface(-name=>"./images/button-pause-raised.png");
# $imgsurfaces->{button_skip_depressed} = new SDL::Surface(-name=>'./images/button-skip-depressed.png');
#    $imgsurfaces->{button_skip_raised} = new SDL::Surface(-name=>'./images/button-skip-raised.png');
#      $imgsurfaces->{arrow_down_white} = new SDL::Surface(-name=>'./images/arrow-down-white.png');
#        $imgsurfaces->{arrow_down_red} = new SDL::Surface(-name=>'./images/arrow-down-red.png');
#        $imgsurfaces->{arrow_up_white} = new SDL::Surface(-name=>'./images/arrow-up-white.png');
#          $imgsurfaces->{arrow_up_red} = new SDL::Surface(-name=>'./images/arrow-up-red.png');

# make speaker button ###########################################
#	my $speaker = new Button(
#        	-name=>'speaker',
#        	-canvas=>$app,
#        	-bg=>$bgcolor,
#        	-mask=>new SDL::Rect(-width => 96, -height =>100, -x=>10, -y=>110),
#        	);
#	{
#        	$speaker->surface(0, $imgsurfaces->{speaker});
#		#$speaker->on_interior_event(SDL_MOUSEBUTTONDOWN, sub { &changepage('albums'); } );
#		$speaker->on_interior_event(SDL_MOUSEBUTTONDOWN, sub { print "Pressed speaker\n"; } );
#	}
#	$pages->{idle}->{'00-speaker'} = $speaker;

# SDL::Timer doesn't seem very stable
#$state->{idleredrawtimer} = new SDL::Timer( sub { &changepage('idle') if ($state->{current_page} eq 'idle'); return 2*1000; }, -delay=>2*1000);
#$state->{idleredrawtimer} = new SDL::Timer( sub { $pages->{$state->{current_page}}->update() if ($state->{current_page} eq 'idle' && ref($pages->{$state->{current_page}})); return 350; }, -delay=>350);
#
#$state->{idleredrawtimer} = new SDL::Timer( sub { 
#		Logger::logger("idleredrawtimer timer running at ".$app->ticks()) if ($debug_timers);
#		if (($state->{current_page} eq 'idle' || 
#		     $state->{current_page} eq 'ripping' ||
#		     $state->{current_page} eq 'oldidle')
#		    && ref($pages->{$state->{current_page}}))  {
#			my $e = new SDL::Event;
#			$e->settype($E_UPDATESTATUS);
#			$e->push();
#		}
#		return 750;
#	}, -delay=>750);
#$state->{animatetimer} = new SDL::Timer( sub {
#		Logger::logger("animate timer running at ".$app->ticks()) if ($debug_timers);
#		my $e = new SDL::Event;
#		$e->settype($E_ANIMATE);
#		$e->push();
#		return 450; 
#	}, -delay=>450);
