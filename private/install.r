REBOL [
	Title: "CureCode Installation Script"
	Author: "Nenad Rakocevic/SOFTINNOV"
	Date: 27/01/2010
	Version: 1.0
]

print "CureCode Installation Script..."

if not find first system/schemes 'MySQL [
	print "...loading MySQL protocol"
	do %mysql-protocol.r
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