-- $Header: /home/cvs/thundaural/database/schema.sql,v 1.1 2004/01/08 08:42:28 jukebox Exp $
CREATE TABLE albums (
  albumid integer,
  performer varchar(128) default NULL,
  name varchar(128) NOT NULL default '',
  cddbid varchar(8) NOT NULL default '',
  length int(11) default NULL,
  riptime int(11) default NULL,
  tracks int(11) NOT NULL default '0',
  coverartfile varchar(128) default NULL,
  PRIMARY KEY  (albumid)
);
CREATE TABLE genres (
  genreid integer,
  genre varchar(64) NOT NULL default '',
  PRIMARY KEY  (genreid),
  UNIQUE (genre)
);
CREATE TABLE playhistory (
  playhistoryid integer primary key,
  trackid int(11) NOT NULL default '0',
  devicename char(32) NOT NULL default '',
  requestedat int(11) default NULL,
  action varchar(32) default 'queued',
  actedat int(11) default NULL
);
CREATE TABLE tracks (
  trackid integer,
  albumid int(11) NOT NULL default '0',
  performer varchar(128) NOT NULL default '',
  length int(11) default NULL,
  name varchar(128) NOT NULL default '',
  albumorder int(11) NOT NULL default '0',
  genreid int(11) default NULL,
  popularity float default NULL,
  rank int(11) default NULL,
  filename varchar(128) NOT NULL default '',
  riperrors varchar(24) default NULL,
  PRIMARY KEY  (trackid)
);
