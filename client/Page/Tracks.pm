#!/usr/bin/perl

package Page::Tracks;

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
use ScrollArea;

use Album;

our @ISA = qw( Page );

my $transparent = new SDL::Color(-r=>1,-g=>128,-b=>254);

my $titlefontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $titlefontsize = 21;
my $aifont = new SDL::TTFont(-name=>$titlefontfile, -size=>17, -bg=>new SDL::Color(-r=>196,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $titlefont = new SDL::TTFont(-name=>$titlefontfile, -size=>$titlefontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $trackfontfile = "/usr/share/fonts/msfonts/arial.ttf";
my $trackfontsize = 35;
my $trackfont = new SDL::TTFont(-name=>$trackfontfile, -size=>$trackfontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));
my $trackfontsmall = new SDL::TTFont(-name=>$trackfontfile, -size=>$trackfontsize*.75, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $tinfofontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $tinfofontsize = 20;
my $tinfofont = new SDL::TTFont(-name=>$tinfofontfile, -size=>$tinfofontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $nexttfontfile = "/usr/share/fonts/msfonts/georgia.ttf";
my $nexttfontsize = 14;
my $nexttfont = new SDL::TTFont(-name=>$nexttfontfile, -size=>$nexttfontsize, -bg=>new SDL::Color(-r=>160,-g=>160,-b=>160), -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

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

	$this->{-albums} = $o{-albums};
	die("passed argument for -albums not an Album object") if (!ref($this->{-albums}) && !$this->{-albums}->isa('Albums'));

	$this->{-imgsurfaces}->{arrow_down_white} = new SDL::Surface(-name=>'./images/arrow-down-white.png');
	$this->{-imgsurfaces}->{arrow_down_red} = new SDL::Surface(-name=>'./images/arrow-down-red.png');
	$this->{-imgsurfaces}->{arrow_up_white} = new SDL::Surface(-name=>'./images/arrow-up-white.png');
	$this->{-imgsurfaces}->{arrow_up_red} = new SDL::Surface(-name=>'./images/arrow-up-red.png');

	$this->{-storagedir} = '/home/storage';

	$this->{-albumid} = 0;

	$this->{-tracksshowing} = [];

	$this->_make();
	Logger::logger("default channel is ".$this->{-channel});

	return $this;
}

sub _make {
	my $this = shift;

	my $topline = $this->{-rect}->y();

	my $output = new Button(
			-name=>'00-output',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>150, -height=>50, -x=>10, -y=>400)
			);
	my $outputs = $this->{-server}->devices('play');
	if (scalar(@$outputs) > 1) {
		my $first;
		foreach my $o (@$outputs) {
			my $x = new SDL::Surface(-width=>150, -height=>50);
			$x->display_format();
			$x->fill(0, new SDL::Color(-r=>140, -g=>140, -b=>140));
			my $fw = $tinfofont->width($o);
			my $fh = $tinfofont->height();
			$tinfofont->print($x, ((150-$fw)/2), ((50-$fh)/3)*2, $o);
			$nexttfont->print($x, 2, 2, "play to...");
			$output->surface($o, $x);
			$first = $o if (!$first);
		}
		$output->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub {
				$this->{-channel} = $this->cycle_outputs($this->{-channel});
				$output->draw($this->{-channel});
				Logger::logger("will queue new tracks on %s", $this->{-channel});
			} );
		$output->frame($first);
		$this->{-channel} = $first;
		$this->add_widget($output);
	} else {
		$this->{-channel} = $outputs->[0];
	}

	my $albumpic = new Button(
			-name=>'00-albumcover',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>200, -height=>200, -x=>10, -y=>$topline+($titlefont->height*2)+10)
			);
	$albumpic->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
			$this->{-appstate}->{current_page} = 'albums';
		} );
	$this->add_widget($albumpic);

	my $albuminfo = new Button(
			-name=>'00-albuminfo',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>200, -height=>230, -x=>10, -y=>480)
			);
	$this->add_widget($albuminfo);

	my $albumtitle = new Button(
			-name=>'00-albumtitle',
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>1004, -height=>($titlefont->height*2)+2, -x=>10, -y=>$topline)
			);
	$this->add_widget($albumtitle);

	my $basesize = $trackfont->height + $tinfofont->height;
	my $xx1 = $this->{-rect}->height() / $basesize;
	$xx1 = int($xx1) - 1;
	my $tlheight = $basesize * $xx1;
	#Logger::logger("lines = $xx1, tlheight = $tlheight");
	my $tracklist = new ScrollArea(
			-name=>'00-tracklist',
			-canvas=>$this->{-canvas},
			-content=>new SDL::Surface(-width=>10, -height=>10),
			-width=>704,
			#-height=>$basesize * 9, # make sure this fits on the screen!
			-height=>$tlheight,
			-x=>220,
			-y=>$topline+($titlefont->height*2)+10,
			-pagesize=>$basesize
			);
	$tracklist->predraw( sub { &main::draw_background($this->widget('00-tracklist')->mask(), $this->{-canvas}); } );
	$tracklist->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
			my $albumorder = $tracklist->determine_line(@_, $trackfont->height+$tinfofont->height);
			my $trackref = sprintf("%d/%d", $this->{-albumid}, $albumorder);
			Logger::logger("selected track $trackref");
			$this->{-server}->play($trackref, $this->{-channel});
			$this->{-appstate}->{current_page} = 'idle';
		} );
	$this->add_widget($tracklist);

	# make UP button
	my $upbutton = new Button(
		-name=>'00-up',
		-canvas=>$this->{-canvas},
		-mask=>new SDL::Rect(-width => 66, -height => 75, -x=>945, -y=>$topline+($titlefont->height*2)+10)
		);
	$upbutton->surface(0, $this->{-imgsurfaces}->{arrow_up_white});
	$upbutton->surface(1, $this->{-imgsurfaces}->{arrow_up_red});
	$upbutton->frame(0);
	$upbutton->predraw( sub { &main::draw_background($this->widget('00-up')->mask(), $this->{-canvas}); } );
	$upbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $this->scroll_tracks(-1); } );
	$this->add_widget($upbutton);

	# make DOWN button
	my $downbutton = new Button(
		-name=>'00-down',
		-canvas=>$this->{-canvas},
		-mask=>new SDL::Rect(-width => 66, -height => 75, -x=>945, -y=>$topline+($titlefont->height*2)+10 + (610-($titlefont->height*2)-20-50) )
		);
	$downbutton->surface(0, $this->{-imgsurfaces}->{arrow_down_white});
	$downbutton->surface(1, $this->{-imgsurfaces}->{arrow_down_red});
	$downbutton->frame(0);
	$downbutton->predraw( sub { &main::draw_background($this->widget('00-down')->mask(), $this->{-canvas}); } );
	$downbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { $this->scroll_tracks(+1); } );
	$this->add_widget($downbutton);
}

sub scroll_tracks {
	my $this = shift;
	my $dir = shift;

	my $upbutton = $this->widget('00-up');
	my $downbutton = $this->widget('00-down');
	my $tracklist = $this->widget('00-tracklist');
	if ($dir < 0) {
		$downbutton->frame(0);
		$upbutton->frame(1);
		$upbutton->draw();
		$tracklist->scrollbypage($dir);
		$this->queue_widget_frame('00-up', 0);
	}

	if ($dir > 0) {
		$upbutton->frame(0);
		$downbutton->frame(1);
		$downbutton->draw();
		$tracklist->scrollbypage($dir);
		$this->queue_widget_frame('00-down', 0);
	}
	$upbutton->hide($tracklist->at_top());
	$upbutton->draw();
	$downbutton->hide($tracklist->at_bottom());
	$downbutton->draw();
}

sub now_viewing {
	my $this = shift;

	$this->SUPER::now_viewing();

	my $albumid = $this->{-appstate}->{albumid};
	$this->{-albumid} = $albumid;
	
	Logger::logger("getting tracks for $albumid");
	my $al = new Album(-albumid=>$albumid);

	$this->widget('00-tracklist')->reset();
	$this->widget('00-albumcover')->surface(0, $this->_make_album_cover($albumid));

	my $aitit = new SDL::Surface(-width=>1004, -height=>($titlefont->height*2)+2);
	$aitit->display_format();
	$aitit->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
	$aitit->fill(new SDL::Rect(-width=>1004,-height=>($titlefont->height*2)+2), $transparent);
	# draw top line
	#$aitit->fill(new SDL::Rect(-width=>1004,-height=>2,-x=>0,-y=>0), new SDL::Color(-r=>255, -g=>0, -b=>0));
	# draw bottom line
	#$aitit->fill(new SDL::Rect(-width=>1004,-height=>2,-x=>0,-y=>($titlefont->height*2)-1), new SDL::Color(-r=>255, -g=>0, -b=>0));
	my $line = 0;
	my @titlelines = ( $al->name(), $al->performer() );
	foreach my $string ( @titlelines ) {
		if ($string) {
			my $w = $titlefont->width($string);
			my $xpos = (1004 - $w) / 2;
			$titlefont->print($aitit, $xpos, $line*($titlefont->height), $string);
		}
		$line++;
	}
	$this->widget('00-albumtitle')->surface(0, $aitit);

	my $tracks = $al->tracks();

	my $aisur = new SDL::Surface(-width=>200, -height=>230);
	$aisur->display_format();
	$aisur->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
	$aisur->fill(0, $transparent);
	my $infolines = {
			#"Rank"=>sub{my($rt,$tt)=$al->ranking; sprintf("%d/%d", $rt, $tt); },
			#"Album ID"=>sub{$al->albumid},
			#"CDDB ID"=>sub{$al->cddbid},
			"Tracks"=>sub{scalar @$tracks},
			"Length"=>sub{$this->sectotime($al->length(), my $short=1)}
			};
	$line = 0;
	for my $k (keys %{$infolines}) {
		$tinfofont->print($aisur, 0, $line*($tinfofont->height), sprintf("%s: %s", $k, &{$infolines->{$k}}));
		$line++;
	}
	$this->widget('00-albuminfo')->surface(0, $aisur);

	my $trlsize = (scalar @$tracks) * ($trackfont->height + $tinfofont->height);

	my $trlcon = new SDL::Surface(-width=>704,-height=>$trlsize, -flags=>SDL::SDL_SRCCOLORKEY);
	$trlcon->display_format();
	$trlcon->fill(0, $transparent);
	$trlcon->set_color_key(SDL::SDL_SRCCOLORKEY, $transparent);
	$this->{-tracksshowing} = [@{$tracks}];
	my $basesize = $trackfont->height + $tinfofont->height;
	$line = 0;
	my $maxwidth = $this->widget('00-tracklist')->width();

	$trlcon->fill(new SDL::Rect(-width=>1004,-height=>2,-x=>0,-y=>$line*$basesize), new SDL::Color(-r=>190, -g=>190, -b=>190));
	foreach my $t (@$tracks) {
		eval {
			my $string = sprintf("%d. %s", $line+1, $t->name());
			my $width = $trackfont->width($string);
			if ($width <= $maxwidth) {
				$trackfont->print($trlcon, 0,  $line*$basesize, $string);
			} else {
				$trackfontsmall->print($trlcon, 0, $line*$basesize+($trackfont->height *.13), $string);
				#$trackfontsmall->print($trlcon, 0, $line*$basesize, $string);
			}
		};
		eval {
			my @data = ();
			if ($t->performer() ne $al->performer()) {
				push(@data, $t->performer());
			}
			push(@data, sprintf("%s of %s", $this->sectotime($t->length(), my $short=1), $t->genre()));
			my $rt = $t->rank();
			$rt = $this->english_rank($rt);
			push(@data, "ranked $rt") if ($rt);
			my $pop = $t->popularity();
			push(@data, ($pop+0) ? sprintf('popularity %.4f', $pop) : 'never played');
			my $d = join(', ', @data);
			$tinfofont->print($trlcon, 50, ($line*$basesize)+$trackfont->height, $d);
		};
		$line++;
		# draw dividing line
		$trlcon->fill(new SDL::Rect(-width=>1004,-height=>2,-x=>0,-y=>$line*$basesize), new SDL::Color(-r=>190, -g=>190, -b=>190));
	}
	$this->widget('00-tracklist')->content($trlcon);
	$this->widget('00-tracklist')->scrolluntil($trlcon->height());
	$this->widget('00-up')->frame(0);
	$this->widget('00-down')->frame(0);
	$this->widget('00-up')->hide(1); # setting the content resets the offset to the top, so hide the up button
	if ($trlsize <= $this->widget('00-tracklist')->height() ) {
		# don't show the scroll buttons if the content is smaller than the canvas
		$this->widget('00-down')->hide(1);
	} else {
		$this->widget('00-down')->hide(0);
	}

	0; #draw for us
}

sub _make_album_cover($) {
	my $this = shift;
	my $alid = shift;

	my $x;
	my $failed = 1;
	my $file = $this->{-albums}->coverartfile($alid);
	if ($file) {
		$file = sprintf('%s/%s', $this->{-storagedir}, $file);
		if (-s $file) {
			eval {
				$x = new SDL::Surface(-name=>$file);
			};
			$failed = 0 if (!$@);
		}
	}
	if ($failed) {
		$x = new SDL::Surface(-width=>275, -height=>275);
		$x->display_format();
		$x->fill(0, new SDL::Color(-r=>180, -g=>180, -b=>180));
		my $g = 0;
		$trackfontsmall->print($x, 0, $g, sprintf("%s ", $this->{-albums}->performer($alid)));
		$g += $trackfontsmall->height();
		$trackfontsmall->print($x, 0, $g, sprintf("%s ", $this->{-albums}->name($alid)));
	}
	return $x;
}

sub cycle_outputs {
	my $this = shift;
	my $cur = shift;

	my $o = $this->{-server}->devices('play');
	my $out = [ @$o, @$o ]; # last + 1 will now equal first
	my $ret;
	my $takenext = 0;
	foreach my $o (@$out) {
		return $o if ($takenext);
		$takenext = 1 if ($o eq $cur);
	}
	return $out->[0];
}

sub sectotime {
	my $this = shift;
	my $sec = shift || 0;
	my $short = shift || 0;

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

sub english_rank {
	my $this = shift;
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
	return "eleventh" if ($rank == 11);
	return "twelveth" if ($rank == 12);
	return "thirteenth" if ($rank == 13);
	return "fourteenth" if ($rank == 14);
	return $rank."st" if ($rank =~ m/1$/);
	return $rank."nd" if ($rank =~ m/2$/);
	return $rank."rd" if ($rank =~ m/3$/);
	return $rank."th";
}

1;

