#!/usr/bin/perl

package SDL::Surface;

use strict;
use warnings;
use Storable qw(freeze thaw);
use Data::Dumper;

my %_copied_surfs = ();

sub serialize {
    goto &serialize_storable;
}

sub serialize_memset {
    my $surface = shift;

    my $p = ${$surface}+0;
    return $p;
}

sub serialize_storable {
    my $surface = shift;

    #printf("serializing surface at 0x%x\n", $$surface);
    my $width = $surface->width();
    my $height = $surface->height();
    my $depth = $surface->bpp();
    my $pitch = $surface->pitch();
    my $flags = $surface->flags();
    my $rmask = $surface->Rmask();
    my $gmask = $surface->Gmask();
    my $bmask = $surface->Bmask();
    my $amask = $surface->Amask();
    my $pixels = $surface->pixels();

    my $s = {
        -width=>$width,
        -height=>$height,
        -depth=>$depth,
        -pitch=>$pitch,
        -flags=>$flags,
        -Rmask=>$rmask,
        -Gmask=>$gmask,
        -Bmask=>$bmask,
        -Amask=>$amask,
        -from=>$pixels};

    return freeze($s);
}

sub unserialize {
    goto &unserialize_storable;
}

sub unserialize_memset {
    my $d = shift;

    my $p = $d+0;
    if ($_copied_surfs{$p}) {
        return $_copied_surfs{$p};
    }
    my $x = bless(\$p, __PACKAGE__);
    $x->display_format();
    $_copied_surfs{$p} = $x;
    print Dumper(\%_copied_surfs);
    return $x;
}

sub unserialize_storable {
    my $d = shift;
    my $s = thaw($d);

    $s = new SDL::Surface(%{$s});
    $s->display_format();
    return $s;
}

package SDL::TTFont;

use strict;
use warnings;

use Carp;
use Thundaural::Logger qw(logger);

sub print_lines {
    my $this = shift;
    $this->print_lines_justified(-1, @_);
}

sub print_lines_justified {
    my $this = shift;
    my %o = @_;
    my $justification = $o{justification} || $o{just};
    my $surface = $o{surface} || $o{surf};
    my $x = $o{x};
    my $y = $o{y};
    my $maxwidth = $o{maxwidth};
    my @lines;
    if (ref($o{lines}) eq 'ARRAY') {
        @lines = @{$o{lines}};
    }

    # specify $x relative to the justification
    #   0 ------------- 50 ------------ 100
    #   (Left -1)   (Center 0)   (Right +1)

    $x = int($x);
    $y = int($y);

    my $height = $this->height();
    my $newx = $x;
    my $maxx = $surface->width();
    foreach my $l (@lines) {
        $l =~ s/\t/       /g;
        if ($l =~ m/^\s*$/) { $l = ' '; };
        if ($justification == 0) {
            my $w = $this->width($l);
            $newx = $x - int($w / 2);
        } elsif ($justification == 1) {
            my $w = $this->width($l);
            $newx = $x - $w;
        }
        # else --- nothing to do for left justification (-1)
        $this->print($surface, $newx, $y, $l);
        $y += $height;
    }
    return $y;
}

sub wrap {
    my $this = shift;
    my $rect = shift;
    my @lines = @_;
    my @ret = ();

    my $maxlines = int($rect->height() / $this->height());
    my $width = $rect->width() - 10;

    while (@lines) {
        my $l1 = shift @lines;
        $l1 =~ s/\s+$//g unless ($l1 eq ' ');
        my $l2 = '';
        while (my $x = $this->width($l1) > $width) {
            my($lx, $space, $lastword) = $l1 =~ m/^(.+)(\s)\s*([^ ]+)$/;
            $l1 = $lx if ($lx);
            $l2 = "$lastword$space$l2" if ($lastword);
        }
        unshift(@lines, $l2) if ($l2);
        push(@ret, $l1);
        last if ((scalar @ret) >= $maxlines);
    }
    #my $padded = 0;
    #while ((scalar @ret) < $maxlines)) {
    #    push(@ret, ' ');
    #    $padded++;
    #}
    return @ret;
}

package SDL::Rect;

use strict;
use warnings;
use Storable qw(freeze thaw);

sub serialize {
    my $rect = shift;

    #printf("serializing rect at 0x%x\n", $$rect);
    my $r = {-height=>$rect->height(), -width=>$rect->width(), -x=>$rect->x(), -y=>$rect->y()};
    return freeze($r);
}

sub unserialize {
    my $d = shift;
    my $r = thaw($d);
    return new SDL::Rect(%{$r});
}

sub tohash {
    my $rect = shift;

    my %r = (-height=>$rect->height(), -width=>$rect->width(), -x=>$rect->x(), -y=>$rect->y());
    return %r;
}

sub tostr {
    my $this = shift;

    return sprintf('%d,%d %dx%d', $this->x, $this->y, $this->width, $this->height);
}

# tricky here 
#package SDL::Surface;
#use Data::Dumper;
#my %_copied_surfs = ();
#sub create_from_pointer {
#    my $p = $_[0]+0;
#    if ($_copied_surfs{$p}) {
#        return $_copied_surfs{$p};
#    }
#    my $x = bless(\$p, __PACKAGE__);
#    $_copied_surfs{$p} = $x;
#    print Dumper(\%_copied_surfs);
#    return $x;
#}


1;


