
package Genre;

# $Header: /home/cvs/thundaural/client/Genre.pm,v 1.1 2003/11/17 06:12:23 jukebox Exp $

use strict;

sub new {
	my $this = {};
	bless $this;
                                                                                                                                                             
	$this->{-dbh} = $main::dbh;
	$this->{-data} = {};
	$this->_populate();
                                                                                                                                                               
	return $this;
}

sub _populate {
	my $this = shift;
	my $q = "select * from genres";
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute;
	while(my $x = $sth->fetchrow_hashref) {
		$this->{-data}->{$x->{genreid}} = $x->{genre};
		$this->{-data}->{$x->{genre}} = $x->{genreid};
	}
	$sth->finish;
}

sub get {
	my $this = shift;
	my $id = shift;
	return $this->{-data}->{$id};
}

1;
