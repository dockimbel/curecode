REBOL []

random/seed now/time/precise 

if not find first system/schemes 'MySQL [
	do %mysql-protocol.r
]

make-text: has [out][
	clear out: ""
	loop 32 [append out #"a" + ((random 26) - 1)]
	out
]
prin "Database root "
db: open mysql://root:?@localhost/bugs


send-sql db rejoin [ {
	INSERT INTO users VALUES (
		NULL,
		'dk1',
		'098F6BCD4621D373CADE4E832627B4F6',
		'default@curecode.org',
		'00000000000000000000000000000000',
		NOW(),
		2,
		NOW()
	)}
]
send-sql db rejoin [
	"INSERT INTO projects VALUES (NULL,'Test','This is a test project',0,0)"
]
repeat ver 4 [
	send-sql db rejoin [
		"INSERT INTO versions VALUES (NULL,2,'1." ver "',0)"
	]
]
send-sql db rejoin ["INSERT INTO categories VALUES (NULL,2,'User Interface',0)"]
send-sql db rejoin ["INSERT INTO categories VALUES (NULL,2,'Security',0)"]
send-sql db rejoin ["INSERT INTO categories VALUES (NULL,2,'Text',0)"]
send-sql db rejoin ["INSERT INTO categories VALUES (NULL,2,'Performances',0)"]


counts: [0 0 0 0]

repeat cnt 10000 [
	either zero? cnt // 1000 [prin newline prin cnt][
		if zero? cnt // 100 [prin #"."]
	]
	poke counts 2 counts/2 + 1
	send-sql db rejoin [ 
		"INSERT INTO tickets VALUES (NULL,"
		2 ","
		"'" join make-text "',"
		"'" join make-text "',"
		"'" join make-text "',"
		1 + random 4 ","
		1 + random 4 ","
		1 + random 4 ","
		random 8 ","
		random 7 ","
		random 9 ","
		random 6 ","
		random 6 ","
		"0,"
		2 ","
		"NOW(), NOW())"
	]
]

repeat cnt 4 [
	send-sql db rejoin ["UPDATE projects SET count=" counts/2 " WHERE id=" 2]
]

close db

halt