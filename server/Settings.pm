
package Settings;

use strict;

eval "use TAProgramLocations;";
die("please run the checkdeps script to generate the TAProgramLocations.pm file\n")
	if ($@);

my $_storagedir = '/home/storage';

my $_dbfile = "$_storagedir/db/data.db";

my $_listenport = 9000;

my $_defaultplaydevice = 'main';

my $_devices = {
	'main'=>{
		'_order'=>1,
		'play'=>'/dev/dsp',
		'mixer'=>'/dev/mixer',
		},
#	'backup'=>{
#		'_order'=>2,
#		'play'=>'/dev/dsp1',
#		'mixer'=>'/dev/mixer1',
#		},
	'cdrom'=>{
		'_order'=>1,
		'read'=>'/dev/cdrom',
		},
	'oggremote'=>{
		'command'=>TAProgramLocations::ogg123().' -d oss -o dsp:${DEVICEFILE} -R -',
		},
	'ripcdrom'=>{
		'command'=>'./ripdisc.pl --dbfile ${DBFILE} --device ${DEVICEFILE} --storagedir ${STORAGEDIR}',
		},
	'volumeset'=>{
		# always keep pcm at 100
		'command'=>TAProgramLocations::aumix().' -d ${DEVICEFILE} -w 100 -v${VOLUME}',
		},
	'volumequery'=>{
		'command'=>TAProgramLocations::aumix().' -d ${DEVICEFILE} -q',
		},
		
};

# no offical support for MP3 yet
# {
#	my $x1 = eval { return TAProgramLocations::mpg123(); };
#	my $x2 = eval { return TAProgramLocations::mpg321(); };
#	my $x = $x1 ? $x1 : $x2;
#	if ($x) {
#		$_devices->{'mp3remote'} = { 'command'=>$x.' -o oss -a ${DEVICEFILE} -R -' };
#	}
#}

sub storagedir {
	return $_storagedir;
}

sub listenport {
	return $_listenport;
}

sub dbfile {
	return $_dbfile;
}

sub default_play_device {
	return $_defaultplaydevice;
}

sub get($$) {
	my $l1 = shift;
	my $l2 = shift;

	if (exists($_devices->{$l1})) {
		if (exists($_devices->{$l1}->{$l2})) {
			return $_devices->{$l1}->{$l2};
		}
	}
	return undef;
}

sub get_of_type($) {
	my $type = shift;

	my @ret = ();
	foreach my $k (keys %$_devices) {
		my %x = %{$_devices->{$k}};
		foreach my $v1 (keys %x) {
			if ((!$type) || ($type && $type eq $v1)) {
				push(@ret, {devicename=>$k, type=>$v1});
			}
		}
	}
	return [ sort { $_devices->{$a->{devicename}}->{_order} cmp $_devices->{$b->{devicename}}->{_order} } @ret ];
}

1;

