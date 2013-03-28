#DROP DATABASE IF EXISTS bugs;
#CREATE DATABASE IF NOT EXISTS bugs;
#USE bugs;

DROP TABLE IF EXISTS projects;
CREATE TABLE projects (
	id			INT(16) 	PRIMARY KEY AUTO_INCREMENT,
	name		VARCHAR(32) NOT NULL,
	description	TEXT,
	private		BOOL 		NOT NULL,
	count		INT(16)
) ;
INSERT INTO projects VALUES (NULL,'All Projects','Virtual project for global view',0,0);

DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
	id			INT(32)  PRIMARY KEY AUTO_INCREMENT,	
	project		INT(16)  NOT NULL,
	brief		VARCHAR(128) NOT NULL,
	description	TEXT 	 NOT NULL,
	code		TEXT,
	version		INT(16)  NOT NULL,
	fixedin		INT(16)  NOT NULL,
	category	INT(8)   NOT NULL,
	severity	INT(8)   NOT NULL,
	status		INT(8)   NOT NULL,
	resolution	INT(8)   NOT NULL,
	priority	INT(8)   NOT NULL,
	reproduce	INT(8)   NOT NULL,
	type 		INT(32)	 NOT NULL,
	platform 	INT(32)	 NOT NULL,
	comments	INT(8)   NOT NULL,
	user		INT(16)  NOT NULL,
	created		DATETIME NOT NULL,
	modified	DATETIME NOT NULL,
	closed		DATETIME DEFAULT NULL,
	INDEX (
		project, version, fixedin, category,
		severity, priority, status, resolution, user, 
		created, closed
	)
);

DROP TABLE IF EXISTS logs;
CREATE TABLE logs (
	id		INT(32)  	PRIMARY KEY AUTO_INCREMENT,
	ticket	INT(32)  	NOT NULL,
	date	DATETIME  	NOT NULL,
	user	VARCHAR(32) NOT NULL,
	action	INT(8)		NOT NULL,
	field	INT(8)		NOT NULL,
	opt_id	INT(32),
	old		INT(16),
	new		INT(16),
	msg		TEXT,
	INDEX (ticket, field, new, date)
);

DROP TABLE IF EXISTS comments;
CREATE TABLE comments (
	id		INT(32)  PRIMARY KEY AUTO_INCREMENT,
	ticket	INT(32)  NOT NULL,
	comment	TEXT  	 NOT NULL,
	user	INT(16)  NOT NULL,
	created	DATETIME NOT NULL,
	INDEX (ticket)
);

DROP TABLE IF EXISTS users;
CREATE TABLE users (
	id		INT(16) 	 PRIMARY KEY AUTO_INCREMENT,
	login	VARCHAR(32)  NOT NULL,
	pasw	VARCHAR(32)  NOT NULL,
	email	VARCHAR(128) NOT NULL,
	vkey	VARCHAR(32)	 DEFAULT NULL,
	vdate	DATETIME 	 DEFAULT NULL,
	role	INT(8)  	 NOT NULL,
	deleted	BOOL		 NOT NULL,
	created	DATETIME 	 NOT NULL,
	modified DATETIME
);

DROP TABLE IF EXISTS rights;
CREATE TABLE rights (
	id		INT(16)	PRIMARY KEY AUTO_INCREMENT,
	user	INT(16) NOT NULL,
	project	INT(16) NOT NULL,
	role	INT(8)  NOT NULL,
	INDEX (user)
);

DROP TABLE IF EXISTS prefs;
CREATE TABLE prefs (
	id		INT(16) PRIMARY KEY AUTO_INCREMENT,
	user	INT(16) NOT NULL,
	data	TEXT NOT NULL,
	INDEX (user)
);

DROP TABLE IF EXISTS files;
CREATE TABLE files (
	id			INT(16) PRIMARY KEY AUTO_INCREMENT,
	ticket		INT(32)  NOT NULL,
	name		VARCHAR(128) NOT NULL,
	file		VARCHAR(32) NOT NULL,
	created		DATETIME NOT NULL,
	user		INT(16) NOT NULL,
	INDEX (ticket, file)
);

DROP TABLE IF EXISTS versions;
CREATE TABLE versions (
	id		INT(16)		PRIMARY KEY AUTO_INCREMENT,
	project	INT(16) 	NOT NULL,
	label	VARCHAR(32) NOT NULL,
	deleted	BOOL 		NOT NULL
);
INSERT INTO versions VALUES (NULL,0,'n/a',0);

DROP TABLE IF EXISTS categories;
CREATE TABLE categories (
	id		INT(16)		PRIMARY KEY AUTO_INCREMENT,
	project	INT(16) 	NOT NULL,
	label	VARCHAR(32) NOT NULL,
	deleted	BOOL 		NOT NULL,
	position INT(8) 	DEFAULT 0
);
INSERT INTO categories VALUES (NULL,0,'n/a',0,0);

DROP TABLE IF EXISTS severities;
CREATE TABLE severities (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,
	label	VARCHAR(32) NOT NULL
);
INSERT INTO severities (label) VALUES
	('not a bug'),
	('trivial'),
	('text'),
	('tweak'),
	('minor'),
	('major'),
	('crash'),
	('block');

DROP TABLE IF EXISTS statuses;
CREATE TABLE statuses (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,
	label	VARCHAR(32) NOT NULL
);
INSERT INTO statuses (label) VALUES
	('submitted'),
	('reviewed'),
	('problem'),
	('waiting'),
	('deferred'),
	('dismissed'),
	('pending'),
	('built'),
	('tested'),
	('complete');

DROP TABLE IF EXISTS resolutions;
CREATE TABLE resolutions (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,
	label	VARCHAR(32) NOT NULL
);
INSERT INTO resolutions (label) VALUES
	('open'),
	('fixed'),
	('reopened'),
	('unable to reproduce'),
	('not fixable'),
	('duplicate'),
	('no change required'),
	('suspended'),
	('won\'t fix');

DROP TABLE IF EXISTS priorities;
CREATE TABLE priorities (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,
	label	VARCHAR(32) NOT NULL
);
INSERT INTO priorities (label) VALUES
	('none'),
	('low'),
	('normal'),
	('high'),
	('urgent'),
	('immediate');

DROP TABLE IF EXISTS roles;
CREATE TABLE roles (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,
	label	VARCHAR(32) NOT NULL
);
INSERT INTO roles (label) VALUES
	('Viewer'),
	('Reporter'),
	('Developer'),
	('Admin');

DROP TABLE IF EXISTS reproduces;
CREATE TABLE reproduces (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,
	label	VARCHAR(32) NOT NULL
);
INSERT INTO reproduces (label) VALUES
	('Always'),
	('Sometimes'),
	('Random'),
	('Have not tried'),
	('Unable to reproduce'),
	('Not applicable');

DROP TABLE IF EXISTS types;
CREATE TABLE types (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,	
	label	VARCHAR(32) NOT NULL
);
INSERT INTO types (label) VALUES
	('Bug'),
	('Wish'),
	('Issue'),
	('Note'),
	('Nuts');
	
DROP TABLE IF EXISTS platforms;
CREATE TABLE platforms (
	id		INT(16) 	PRIMARY KEY AUTO_INCREMENT,	
	label	VARCHAR(32) NOT NULL
);
INSERT INTO platforms (label) VALUES
	('All'),
	('N/A'),
	('Windows'),
	('Mac OSX'),
	('Linux x86 libc6'),
	('FreeBSD x86');

INSERT INTO users VALUES (
	NULL,
	'admin',
	'EE10C315EBA2C75B403EA99136F5B48D',
	'default@curecode.org',
	'00000000000000000000000000000000',
	NOW(),
	4,
	0,
	NOW(),
	NOW()
);

