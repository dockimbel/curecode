REBOL [
	Title: "CureCode Installation Script"
	Author: "Nenad Rakocevic/SOFTINNOV"
	Date: 27/01/2010
	Version: 1.0
]

mysql-prot: none

print "CureCode Installation Script..."

if not find first system/schemes 'MySQL [
	print "...loading MySQL protocol from http://sidl.fr/mysql-protocol.r"
	do as-string mysql-prot: read/binary http://sidl.fr/mysql-protocol.r
]
print "...checking server status"
unless attempt [close open/no-wait/direct tcp://localhost:3306 true][
	print "*** Error: MySQL server unreachable on port 3306"
	halt
]

print "^/...creating database"
pass: ask/hide "...database root password (ENTER if none): "
install-pass: either empty? pass [""][join ":" pass]

db: open replace mysql://root$PASS$@localhost/mysql "$PASS$" install-pass
print "...access ok to MySQL server"

db-name: ask "^/...name of the new CureCode database (ENTER for default): "
if empty? trim db-name [db-name: "bugs"]

print "...creating database"
send-sql db replace/all {
    DROP DATABASE IF EXISTS $DB$;
    CREATE DATABASE IF NOT EXISTS $DB$;
    USE $DB$;
} "$DB$" db-name

print "...creating tables"
send-sql db read %build-db.sql
close db

print "...installing mysql-protocol.r"
mysql?: ask "...do you have mysql-protocol.r already installed? (ENTER=no): "
if any [empty? mysql? not parse mysql? ["y" | "yes"]][
	if not mysql-prot [
		print "...downloading http://sidl.fr/mysql-protocol.r"
		mysql-prot: read/binary http://sidl.fr/mysql-protocol.r
	]
	until [
		path: ask "...where to save mysql-protocol.r? "
		if path/1 = #"%" [remove path]
		all [
			path: attempt [to-rebol-file trim path]
			any [
				attempt [write/binary path/mysql-protocol.r mysql-prot true]
				all [print "*** writing file failed!" none]
			]
		]
	]
	msg: {
Please add the following config directive to your %httpd.cfg into the GLOBAL section:

	worker-libs [
		$PATH$
	]
	
}
	replace msg "$PATH$" mold path/mysql-protocol.r
	print msg
]

msg: {
Please add the following webapp definition to your %httpd.cfg file in the domain
config block of your choice :

	webapp [
		virtual-root 	"/curecode/"
		root-dir 		$PATH$
		locales-dir 	%private/instances/default/locales/
		timeout 		00:30
		
		databases 		[
			bugs mysql://root$PASS$@localhost/$DB$
		]
		locals [
			name		"CureCode"
			instance	%default/
		]
	]
}
replace msg "$PATH$" mold first split-path what-dir
replace msg "$PASS$" install-pass
replace/all msg "$DB$" db-name

print msg

print {
Administrator account
---------------------
login: admin
pass:  nimda

Please change admin's password once logged (in Profile menu).
}

print "^/...intallation finished."
halt