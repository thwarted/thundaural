#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/interface.pl,v 1.8 2004/01/09 05:54:07 jukebox Exp $

use strict;
use warnings;

our ($dbh);
our ($iCon);
our ($Albums);
my $bin_logger = '/usr/bin/logger';

#my $usefont = "/tmp/sdltest/electrohar.ttf";
#my $usefont = "/tmp/sdltest/aircut3.ttf";
#my $usefont = "/usr/X11R6/lib/X11/fonts/TTF/luximb.ttf";
#my $usefont = "/usr/share/fonts/msfonts/comic.ttf";
#my $usefont = "/usr/share/fonts/msfonts/tahoma.ttf";
my $debugfontfile = "/usr/share/fonts/msfonts/arialbd.ttf";
my $titlefontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $titlefontsize = 21;
my $trackfontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $trackfontsize = 35;
my $tinfofontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $tinfofontsize = 20;
my $nexttfontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $nexttfontsize = 14;
my $progressfontfile = "/usr/share/fonts/msfonts/arial.ttf";
my $progressfontsize = 14;
#my $nexttfontfile = "/usr/share/fonts/msfonts/georgia.ttf";

my $usesize = 15;

my $WIN_X = 1024;
my $WIN_Y = 768;

my $debug_timers = 0;

use DBI;

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

# interface related stuff
use EventReceiver;
use Button;
use ScrollArea;
use ProgressBar;

use Page::Error;
use Page::Albums;
use Page::OldIdle;
use Page::Tracks;
use Page::Ripping;
use Page::NowPlaying;

our $E_SHOWALBUMS=SDL::SDLK_QUOTE;
our $E_SHOWTRACKS=SDL::SDLK_QUOTEDBL;
our $E_SHOWIDLE=SDL::SDLK_SEMICOLON;
our $E_SHOWERROR=SDL::SDLK_HASH;
our $E_CALLFUNCS=SDL::SDLK_BACKSPACE;
our $E_UPDATESTATUS=SDL::SDLK_COLON;
our $E_ANIMATE=SDL::SDLK_AT;

my $debugfont = new SDL::TTFont(-name=>$debugfontfile, -size=>13, -bg=>new SDL::Color(-r=>255,-g=>255,-b=>255), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $aifont = new SDL::TTFont(-name=>$titlefontfile, -size=>17, -bg=>new SDL::Color(-r=>196,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $titlefont = new SDL::TTFont(-name=>$titlefontfile, -size=>$titlefontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $trackfont = new SDL::TTFont(-name=>$trackfontfile, -size=>$trackfontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $trackfontsmall = new SDL::TTFont(-name=>$trackfontfile, -size=>$trackfontsize*.75, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $tinfofont = new SDL::TTFont(-name=>$tinfofontfile, -size=>$tinfofontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $nexttfont = new SDL::TTFont(-name=>$nexttfontfile, -size=>$nexttfontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $mostrecfont = new SDL::TTFont(-name=>$nexttfontfile, -size=>$nexttfontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>255,-g=>255,-b=>255));
my $progressfont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>new SDL::Color(-r=>140,-g=>140,-b=>140), -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));
my $volumefont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>new SDL::Color(-r=>140,-g=>140,-b=>140), -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));

my $app = &setup($WIN_X, $WIN_Y);
my $imgsurfaces = {};
#$imgsurfaces->{bg} = new SDL::Surface(-name=>'./images/bgfractalbroccoli.png');
$imgsurfaces->{bg} = new SDL::Surface(-name=>'./images/bgmetal2.png');

my $menuarea = new SDL::Rect(-width=>$WIN_X, -height=>98, -x=>0, -y=>0);
my $pagearea = new SDL::Rect(-width=>$WIN_X, -height=>$WIN_Y-94, -x=>0, -y=>98);

my $state = {
	current_page=>'idle',
 	last_page=>'',
	ripping_track=>'',
};

my $pages = {};
$pages->{'error'} = new Page::Error(-canvas=>$app, -rect=>$pagearea, -appstate=>$state),

$iCon = new ClientCommands(-errorfunc=>\&show_error_message, -recoveredfunc=>\&eatevents);
$Albums = new Albums(-server=>$iCon);

$pages->{'albums'} = new Page::Albums(-server=>$iCon, -canvas=>$app, -rect=>$pagearea, -appstate=>$state, -albums=>$Albums);
$pages->{'tracks'} = new Page::Tracks(-server=>$iCon, -canvas=>$app, -rect=>$pagearea, -appstate=>$state, -albums=>$Albums);
#$pages->{'oldidle'} = new Page::OldIdle(-server=>$iCon, -canvas=>$app, -rect=>$pagearea, -appstate=>$state, -albums=>$Albums);
$pages->{'ripping'} = new Page::Ripping(-server=>$iCon, -canvas=>$app, -rect=>$pagearea, -appstate=>$state, -albums=>$Albums);
$pages->{'idle'} = new Page::NowPlaying(-server=>$iCon, -canvas=>$app, -rect=>$pagearea, -appstate=>$state, -albums=>$Albums);


               #$imgsurfaces->{speaker} = new SDL::Surface(-name=>'./images/speaker.png');
       $imgsurfaces->{goto_nowplaying} = new SDL::Surface(-name=>"./images/goto-nowplaying.png");
           $imgsurfaces->{goto_albums} = new SDL::Surface(-name=>'./images/goto-albums.png');
     $imgsurfaces->{start_screensaver} = new SDL::Surface(-name=>"./images/start-screensaver03.png");
       $imgsurfaces->{'ripcdrom-busy'} = new SDL::Surface(-name=>'./images/ripcdrom-busy.png');
       $imgsurfaces->{'ripcdrom-idle'} = new SDL::Surface(-name=>'./images/ripcdrom-idle.png');

        $imgsurfaces->{'nowplaying-0'} = new SDL::Surface(-name=>'./images/nowplaying-speaker0.png');
        $imgsurfaces->{'nowplaying-1'} = new SDL::Surface(-name=>'./images/nowplaying-speaker1.png');
        $imgsurfaces->{'nowplaying-2'} = new SDL::Surface(-name=>'./images/nowplaying-speaker2.png');
        $imgsurfaces->{'nowplaying-3'} = new SDL::Surface(-name=>'./images/nowplaying-speaker3.png');
        $imgsurfaces->{'nowplaying-4'} = new SDL::Surface(-name=>'./images/nowplaying-speaker4.png');
        $imgsurfaces->{'nowplaying-5'} = new SDL::Surface(-name=>'./images/nowplaying-speaker5.png');
        $imgsurfaces->{'nowplaying-6'} = new SDL::Surface(-name=>'./images/nowplaying-speaker6.png');

my $callfuncs = [];

my $menuwidgets = &make_menu_widgets;
#&draw_widgets;

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
			Logger::logger("E_CALLFUNCS: called $funccount subs");
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

sub make_page_error {
	my $errormsg = shift;
	my $buttonerror = new Button(
			-name=>'buttonerror',
			-canvas=>$app,
			-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
			-mask=>new SDL::Rect(-width=>500,-height=>500, -x=>($WIN_X-500)/2, -y=>($WIN_Y-500)/2)
			);
	my $x = new SDL::Surface(-width=>500, -height=>500);
	$x->display_format();
	$x->fill(0, new SDL::Color(-r=>140,-g=>140,-b=>140));
	my $fh = $tinfofont->height;
	my @lines = split(/\n/, $errormsg);
	my $lpos = $fh;
	foreach my $l (@lines) {
		my $fw = $tinfofont->width($l);
		if ($fw) {
			$tinfofont->print($x, ((500-$fw)/2), $lpos, $l);
		}
		$lpos += $fh;
	}
	$buttonerror->surface(0, $x);
	$buttonerror->frame(0);
	
	return {'00-buttonerror'=>$buttonerror};
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
#	my $ni = new Button(
#			-name=>"oldidle",
#			-canvas=>$app,
#			-bg=>$bgcolor,
#			-mask=>new SDL::Rect(-width=>90, -height=>90, -x=>270, -y=>1)
#		);
#	{
#		$ni->predraw( sub { &main::draw_background($ni->mask(), $app); } );
#		$ni->surface(2, $imgsurfaces->{'nowplaying-2'});
#		$ni->frame(2);
#		$ni->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $state->{current_page} = 'oldidle'; } );
#	}
	my $gotoalbums = new Button(
                	-name=>'gotoalbums',
                	-canvas=>$app,
                	-bg=>$bgcolor,
                	-mask=>new SDL::Rect(-width=>90,-height=>90, -x=>160, -y=>2)
                	);
	{
        	$gotoalbums->surface(0, $imgsurfaces->{goto_albums});
		$gotoalbums->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $state->{current_page} = 'albums'; } );
	}
	my $screensaver = new Button(
			-name=>'screensaver',
			-canvas=>$app,
			-bg=>$bgcolor,
			-mask=>new SDL::Rect(-width=>48,-height=>48,-x=>1024-50,-y=>2)
			);
	{
		#$x->set_alpha(SDL_SRCALPHA, 128);
		$screensaver->surface(0, $imgsurfaces->{start_screensaver});
		$screensaver->frame(0);
		$screensaver->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, \&start_screensaver);
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

	return {'00-screensaver'=>$screensaver,
		#'00-ni'=>$ni,
		'00-gotoalbums'=>$gotoalbums,
		'00-gotoripping'=>$gotoripping,
		'00-gotoidle'=>$gotoidle};
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

sub draw_debug_line {
	my $event = shift;
	my $x = new SDL::Rect(-width=>1024, -height=>16, -x=>0, -y=>0);
	$app->fill($x, new SDL::Color(-r=>255,-g=>255,-b=>255));
	$debugfont->print(
			$app,
			1,
			0,
		sprintf("event type %d received at %d location %dx%d", $event->type(), $app->ticks(), $event->motion_x(), $event->motion_y())
		);
}

sub dbconnect {
	my $db_database = 'jukebox';
	my $db_hostname = 'jukebox';
	my $db_port = 3306;
	my $db_user = 'jukebox';
	my $db_pass = 'jukebox';
	my $db_dsn = "DBI:mysql:database=$db_database;host=$db_hostname;port=$db_port";

	my $dbh = DBI->connect($db_dsn, $db_user, $db_pass, {'RaiseError' => 1, 'PrintError'=>1});
	$dbh->trace(1);
	return $dbh;
}

sub setup {
	my ($x, $y) = @_;
	my $app = new SDL::App( -title => 'Jukebox',
				-width => $x,
				-height => $y,
				-depth => 24,
			# can't  go fullscreen, because then the touchscreen doesn't work
			# with a hidden mouse pointer
				-full => 0,
				-flags => SDL::SDL_DOUBLEBUF | SDL::SDL_HWSURFACE | SDL::SDL_HWACCEL );
	my $hostname = `/bin/hostname`;
	chomp $hostname;
	if ($hostname =~ m/jukebox/) {
		SDL::Cursor::show(0);
	}
	return $app;
}

sub adjust_albumoffset($$) {
	my $offset = shift;
	my $amount = shift;
	my $count = $Albums->count;
	my $max = $count - $state->{albumsperpage};

	$state->{lastalbumoffset} = $offset;
	$offset += $amount;

	if ($offset < 0) {
		return 0;
	}
	if ($offset > $max) {
		return $max;
	}
	return $offset;
}

sub english_rank {
	my $rank = shift;

	return $rank if (!$rank);

	return "first" if ($rank == 1);
	return "second" if ($rank == 2);
	return "third" if ($rank == 3);
	return "fourth" if ($rank == 4);
	return "fifth" if ($rank == 5);
	return "sixth" if ($rank == 6);
	return "seventh" if ($rank == 7);
	return "eighth" if ($rank == 8);
	return "ninth" if ($rank == 9);
	return "tenth" if ($rank == 10);
	return $rank."st" if ($rank =~ m/1$/);
	return $rank."nd" if ($rank =~ m/2$/);
	return $rank."rd" if ($rank =~ m/3$/);
	return $rank."th";
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
	system("/usr/local/bin/xscreensaver-command -activate");
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
	Logger::logger("attempt to call \"$AUTOLOAD\" by $p ($f:$l)\n");
	0;
}

1;

__END__ 

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

