#!/usr/bin/perl

package Page::Albums;

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

	# passed in options
	$this->{-server} = $o{-server};
	die if (ref($this->{-server}) ne 'ClientCommands');

	$this->{-canvas} = $o{-canvas};
	die("canvas is not an SDL::Surface") if (!ref($this->{-canvas}) && !$this->{-canvas}->isa('SDL::Surface'));

	$this->{-albums} = $o{-albums}; # new Albums(-server=>$this->{-server});
	die("passed argument for -albums not an Album object") if (!ref($this->{-albums}) && !$this->{-albums}->isa('Albums'));

	$this->{-lastalbumoffset} = -1;
	$this->{-albumoffset} = 0; # 80;

	$this->{-positions} = [ [  91,102], [ 91,386], [ 375,102], [375,386], [ 659,102], [659,386]]; # 275x275
	$this->{-albumsperpage} = scalar @{$this->{-positions}};

	$this->{-imgsurfaces}->{button_next_raised} = new SDL::Surface(-name=>'./images/button-next-raised.gif');
	$this->{-imgsurfaces}->{button_next_depressed} = new SDL::Surface(-name=>'./images/button-next-depressed.gif');
	$this->{-imgsurfaces}->{button_back_raised} = new SDL::Surface(-name=>'./images/button-back-raised.gif');
	$this->{-imgsurfaces}->{button_back_depressed} = new SDL::Surface(-name=>'./images/button-back-depressed.gif');

	$this->{-storagedir} = '/home/storage';

	$this->{-font} = new SDL::TTFont(
				-name=>'/usr/share/fonts/msfonts/georgia.ttf',
				-size=>14,
				-bg=>new SDL::Color(-r=>180,-g=>180,-b=>180),
				-fg=>new SDL::Color(-r=>0,-g=>0,-b=>0)
			);

	$this->_make();

	return $this;
}

sub _make {
	my $this = shift;
	my $bgcolor = new SDL::Color(-r=>160, -g=>160, -b=>160);

	my $backbutton = new Button(
			-name=>'99-back',
			-bg=>$bgcolor,
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>95, -height=>95, -x=>52, -y=>($this->{-canvas}->height()-100))
			);
	$backbutton->surface('raised', $this->{-imgsurfaces}->{button_back_raised});
	$backbutton->surface('depressed', $this->{-imgsurfaces}->{button_back_depressed});
	$backbutton->frame('raised');
	$backbutton->predraw( sub { &main::draw_background($this->widget('99-back')->mask(), $this->{-canvas}); } );
	$backbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
		$this->widget('99-back')->draw('depressed'); 
		$this->queue_widget_frame('99-back', 'raised'); 
		$this->_adjust_albumoffset(-4); 
		$this->update_albums_widgets();
		$this->draw(1);
	} );

	my $nextbutton = new Button(
			-name=>'99-next',
			-bg=>$bgcolor,
			-canvas=>$this->{-canvas},
			-mask=>new SDL::Rect(-width=>95, -height=>95, -x=>877, -y=>($this->{-canvas}->height()-100))
			);
	$nextbutton->surface('raised', $this->{-imgsurfaces}->{button_next_raised});
	$nextbutton->surface('depressed', $this->{-imgsurfaces}->{button_next_depressed});
	$nextbutton->frame('raised');
	$nextbutton->predraw( sub { &main::draw_background($this->widget('99-next')->mask(), $this->{-canvas}); } );
	$nextbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
		$this->widget('99-next')->draw('depressed'); 
		$this->queue_widget_frame('99-next', 'raised');
		$this->_adjust_albumoffset(4); 
		$this->update_albums_widgets();
		$this->draw(1);
	} );

	my $slider = new ProgressBar(
			-name=>"99-slider",
			-canvas=>$this->{-canvas},
			-bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
			-fg=>new SDL::Color(-r=>0x4b, -g=>0x2e, -b=>0x82),
			-line=>1,
			-mask=>new SDL::Rect(
					-width=>877-20-(52+95+20), 
					-height=>40, 
					-x=>52+95+20, 
					-y=>($this->{-canvas}->height()-32-40)),
			#-labelfont=>$progressfont,
			#-labelcolor=>new SDL::Color(-r=>160, -g=>160, -b=>160)
		);
	$slider->predraw( sub { &main::draw_background($this->widget('99-slider')->mask(), $this->{-canvas}); } );
	$slider->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
			my ($sl, $event, $inside) = @_; 
			my $width;
			eval { $width = $sl->mask()->width(); };
			if ($@) {
				Logger::logger("unable to get width of slider bar: $@");
				return;
			}
			my $newoffset = eval { 
				my $x = $width / 100;
				int($inside->[0] / $x); 
			};
			Logger::logger($@) if ($@);
			return if(!defined($newoffset)); 
			Logger::logger("changing to offset $newoffset"); 
			$this->_adjust_albumoffset(sprintf("%.02f", $newoffset /100));
			$this->update_albums_widgets();
			$this->draw(1);
		} );
	$this->add_widget($slider);

	$this->add_widget($backbutton);
	$this->add_widget($nextbutton);
}

sub _adjust_albumoffset($) {
	my $this = shift;
	my $amount = shift;

	my $count = $this->{-albums}->count();
	return if (!$count);

	my $max = $count - $this->{-albumsperpage};
	Logger::logger("count = $count, max = $max");

	if ($amount =~ m/\./) {
		Logger::logger("got $amount, assuming percentage");
		# we were passed a percentage rather than a relative amount
		$this->{-lastalbumoffset} = $this->{-albumoffset};
		$this->{-albumoffset} = $count * $amount;
	} else {
		Logger::logger("got $amount, assuming relative");
		$this->{-lastalbumoffset} = $this->{-albumoffset};
		$this->{-albumoffset} += $amount;
	}

	if ($this->{-albumoffset} > $max) {
		$this->{-albumoffset} = $max;
		$this->widget('99-slider')->pctfull(1);
	} elsif ($this->{-albumoffset} < 0) {
		$this->{-albumoffset} = 0;
		$this->widget('99-slider')->pctfull(0);
	} else {
		my $pc = $this->{-albumoffset} / $count;
		$this->widget('99-slider')->pctfull($pc);
	}
}

sub update {
	# nothing to do
	return;
}

sub now_viewing {
	my $this = shift;

	$this->update_albums_widgets();
	$this->SUPER::now_viewing();
}

sub update_albums_widgets {
	my $this = shift;

	return if ($this->{-lastalbumoffset} == $this->{-albumoffset});
	my @pos = @{$this->{-positions}};
	my $perpage = $this->{-albumsperpage};
	my @widgets = $this->widgets();
	foreach my $al (@widgets) {
		$this->delete_widget($al) if ($al =~ m/^00-album\d+/);
	}

	my $albums = $this->{-albums}->list($this->{-albumoffset}, $perpage);
	foreach my $alid (@$albums) {
		my($x, $y) = @{shift(@pos)};
		#Logger::logger("creating album $alid at $x,$y");
		my $drect = new SDL::Rect(-width=>275, -height=>275, -x=>$x, -y=>$y);
		my $albumbutton = new Button(-name=>"00-album$alid",
						-canvas=>$this->{-canvas},
						-mask=>$drect,
						#-nosync=>1
						);
		$albumbutton->surface(0, $this->_make_album_cover($alid));
		$albumbutton->frame(0);
		$albumbutton->on_interior_event(SDL::SDL_MOUSEBUTTONDOWN, sub { 
				Logger::logger("selected album $alid"); 
				$this->{-appstate}->{albumid} = $alid;
				$this->{-appstate}->{current_page} = 'tracks'; 
			} );
		$this->add_widget($albumbutton);
	}
	$this->{-lastalbumoffset} = $this->{-albumoffset};
	$this->widget('99-back')->hide($this->{-albumoffset} == 0 ? 1 : 0);
	$this->widget('99-back')->frame('raised');
	$this->widget('99-next')->hide($this->{-albumoffset} >= ($this->{-albums}->count() - $perpage) ? 1 : 0);
	$this->widget('99-next')->frame('raised');
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
		$this->{-font}->print($x, 0, $g, sprintf("%s ", $this->{-albums}->performer($alid)));
		$g += $this->{-font}->height();
		$this->{-font}->print($x, 0, $g, sprintf("%s ", $this->{-albums}->name($alid)));
	}
	return $x;
}

sub draw {
	my $this = shift;

	&main::clear_page_area();
	$this->SUPER::draw(@_);
}

1;

