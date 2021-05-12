DROP DATABASE IF EXISTS SEDdatabase_nameSED;
CREATE DATABASE SEDdatabase_nameSED;

DROP TABLE IF EXISTS SEDdatabase_nameSED.users;
CREATE TABLE  SEDdatabase_nameSED.users (
  userID int(11) unsigned NOT NULL auto_increment,
  dateSQL timestamp NOT NULL default CURRENT_TIMESTAMP,
  username varchar(16) NOT NULL UNIQUE,
  password varchar(128) NOT NULL,
  email varchar(255) default NULL UNIQUE,
  emailbounce int(11) unsigned NOT NULL default 0 comment '0=ok >0=bounced holds snsnotifiationID',
  emailcomplaint int(11) unsigned NOT NULL default 0 comment '0=ok >0=complained holds snsnotifiationID',
  sessiontoken1 varchar(16) default NULL,
  sessiontoken2 varchar(16) default NULL,
  sessionipaddress varchar(64) default NULL,
  sessionuseragent varchar(64) default NULL,
  sessionlastdateSQL datetime,
  PRIMARY KEY (userID)
) ENGINE=InnoDB AUTO_INCREMENT=12973 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS SEDdatabase_nameSED.sendemails;
CREATE TABLE  SEDdatabase_nameSED.sendemails (
  sendemailID int(11) unsigned NOT NULL AUTO_INCREMENT,
  dateSQL timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  userID int(11) unsigned NOT NULL,
  sendto varchar(255) NOT NULL DEFAULT '',
  sendfrom varchar(255) NOT NULL DEFAULT '',
  sendsubject varchar(255) NOT NULL DEFAULT '',
  sendmessage varchar(8192) NOT NULL DEFAULT '',
  sendfailures tinyint unsigned NOT NULL DEFAULT '0',
  sent tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (sendemailID)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS SEDdatabase_nameSED.snsnotifications;
CREATE TABLE SEDdatabase_nameSED.snsnotifications (
  snsnotificationID int(11) unsigned NOT NULL AUTO_INCREMENT,
  dateSQL timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  messageid varchar(255) DEFAULT '',
  subject varchar(255) DEFAULT '',
  message varchar(2048) DEFAULT '',
  email varchar(255) DEFAULT '',
  PRIMARY KEY (snsnotificationID)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
