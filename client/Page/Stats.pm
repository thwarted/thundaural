#!/usr/bin/perl

# $Header: /home/cvs/thundaural/client/Page/Stats.pm,v 1.6 2004/03/27 08:19:01 jukebox Exp $

package Page::Stats;

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

my $statsfontfile = "./fonts/Vera.ttf";
my $statsfontsize = 30;
my $xbg = new SDL::Color(-r=>160,-g=>160,-b=>160);
my $statsfont = new SDL::TTFont(-name=>$statsfontfile, -size=>$statsfontsize, -bg=>$xbg, -fg=>new SDL::Color(-r=>0,-g=>0,-b=>0));

my $progressfontfile = "./fonts/Vera.ttf";
my $progressfontsize = 14;
my $progressfont = new SDL::TTFont(-name=>$progressfontfile, -size=>$progressfontsize, -bg=>new SDL::Color(-r=>166, -g=>165, -b=>165), -fg=>new SDL::Color(-r=>32,-g=>32,-b=>32));


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
	$this->{-srect} = new SDL::Rect(-width=>1024-15-15, -height=>$this->{-rect}->height()-40, -x=>15, -y=>$this->{-rect}->y()+20);
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
	$updater->on_event($main::E_UPDATESTATUS, sub { $this->update() if($this->{-appstate}->{current_page} eq 'stats'); } );
	$this->add_widget($updater); # make sure this sorts first

	my $progressbar = new ProgressBar(
                        -name=>"99-diskusage",
                        -canvas=>$this->{-canvas},
                        -bg=>new SDL::Color(-r=>140, -g=>140, -b=>140),
                        -fg=>new SDL::Color(-r=>190, -g=>190, -b=>190),
                        -mask=>new SDL::Rect(
				-width=>$this->{-srect}->width()-20, 
				-height=>16, 
				-x=>$this->{-srect}->x()+10, 
				-y=>$this->{-srect}->y()+$this->{-srect}->height()-32),
                        -labelfont=>$progressfont,
                        -labelcolor=>new SDL::Color(-r=>160, -g=>160, -b=>160)
	);
	$this->add_widget($progressbar);
}

sub now_viewing() {
	my $this = shift;
	$this->SUPER::now_viewing();
	$this->{-last} = {};
	$this->update();
}

sub update {
	my $this = shift;
	my $barcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
	my $blit = 0;

	&main::draw_background($this->{-rect}, $this->{-canvas});

	my $surf = $this->{-s};
	my $g = 10;
	my $indent = 200;

	my $st = $this->{-server}->stats();
	# copy it, so we can modify it
	my %st = %{$st};
	$st = \%st;

	my $ss = Dumper($st);
	my $supsince = time() - $st->{'uptime-server'};
	my $mupsince = time() - $st->{'uptime-machine'};
	my $cupsince = time() - $st->{'uptime-client'};
	delete($st->{'uptime-server'});
	delete($st->{'uptime-machine'});
	delete($st->{'uptime-client'});

	if (!exists($this->{-last}->{stats}) || $this->{-last}->{stats} ne $ss) {
		my @lines = ();
		my $x;

		$x = $st->{albums} || 0;
		push(@lines, $x ? sprintf('%d album%s', $x, ($x == 1 ? '' : 's')) : 'No albums' );

		if ($x = (($st->{albums} || 0) - ($st->{coverartfiles} || 0)) ) {
			push(@lines, sprintf('%d album%s %s missing cover art', $x, ($x == 1 ? '' : 's') , ($x == 1 ? 'is' : 'are') ));
		} else {
			push(@lines, "");
		}
		push(@lines, "");
		$x = $st->{tracks} || 0;
		push(@lines, $x ? ($x == 1 ? '1 track' : "$x total tracks") : 'No tracks' );
		$x = $st->{'tracks-played'};
		push(@lines, sprintf("\t%s tracks successfully played", ($x ? $x : 'No') ));
		$x = $st->{'tracks-skipped'} || 0;
		push(@lines, sprintf("\t%s tracks skipped", ($x ? $x : 'No') ));
		$x = $st->{'tracks-failed'} || 0;
		push(@lines, sprintf("\t%s tracks have had problems playing", ($x ? $x : 'No') ));
		push(@lines, "");
		push(@lines, sprintf("%s total storage space", $this->short_mem($st->{'storage-total'})));
		push(@lines, sprintf("\t%s used", $this->short_mem($st->{'storage-used'})));
		push(@lines, sprintf("\t%s available", $this->short_mem($st->{'storage-available'})));
		push(@lines, "");
		push(@lines, sprintf("Server software up since %s", strftime('%a %b %e %H:%M:%S %Y', localtime($supsince))));
		push(@lines, sprintf("Server machine up since %s", strftime('%a %b %e %H:%M:%S %Y', localtime($mupsince))));
		push(@lines, sprintf("Client connected since %s", strftime('%a %b %e %H:%M:%S %Y', localtime($cupsince))));

		$g += $this->print_lines($surf, $statsfont, 10, $g, @lines);
		$this->{-last}->{stats} = $ss;

		{
			my $w = $this->widget('99-diskusage');
			$w->pctfull($st->{'storage-percentagefull'}/100);
			$w->label(sprintf('storage space - %d%% full', $st->{'storage-percentagefull'}));
		}
		$blit = 1;
	}

	if ($blit) {
		$surf->blit(0, $this->{-canvas}, $this->{-srect});
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
		if ($l =~ m/^\s*$/) { $l = " "; }
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

sub short_mem {
	my $this = shift;
	my $a = shift;

	my $k = $a / 1024;
	my $m = $k / 1024;
	my $g = $m / 1024;

	if ($g > 1) {
		return sprintf('%.1f gigabytes', $g);
	}
	if ($m > 1) {
		return sprintf('%.1f megabytes', $m);
	}
	if ($k > 1) {
		return sprintf('%.1f kilobytes', $k);
	}
	return "$a bytes";
}


1;

