REBOL []

define-cached-queries: does [
	db-cache/define 'bugs [
		severities 	"SELECT id,label FROM severities"
		priorities 	"SELECT id,label FROM priorities"
		roles	 	"SELECT id,label FROM roles"
		statuses	"SELECT id,label FROM statuses"
		reproduces	"SELECT id,label FROM reproduces"
		resolv		"SELECT id,label FROM resolutions"
		projects 	"SELECT id,name  FROM projects WHERE id > 1"
		priv-proj 	"SELECT id,name  FROM projects WHERE private=1"
		pub-proj	"SELECT id,name  FROM projects WHERE private=0"
		types		"SELECT id,label FROM types"
		platforms	"SELECT id,label FROM platforms"
	]
]

enum-reproduces:  does [do-sql/flat 'bugs 'reproduces]
enum-resolv: 	  does [do-sql/flat 'bugs 'resolv]
enum-severities:  does [do-sql/flat 'bugs 'severities]
enum-priorities:  does [do-sql/flat 'bugs 'priorities]
enum-statuses: 	  does [do-sql/flat 'bugs 'statuses]
enum-roles: 	  does [do-sql/flat 'bugs 'roles]
enum-types: 	  does [do-sql/flat 'bugs 'types]
enum-platforms:   does [do-sql/flat 'bugs 'platforms]

enum-projects: func [/priv /public /full][
	do-sql/flat 'bugs any [
		all [priv 	'priv-proj]
		all [public 'pub-proj]
		all [full	"SELECT * FROM projects WHERE id > 1"]
		'projects
	]
]

enum-users: does [
	do-sql/flat 'bugs {
		SELECT 
			users.id,login,email,vdate,roles.label,created 
		FROM
			users,roles
		WHERE
			users.deleted=0
			AND users.role = roles.id
		ORDER BY
			users.id
	}
]

enum-versions: does [
	do-sql/flat 'bugs rejoin [
		"SELECT id,label FROM versions "
		either session/content/project-id = 1 [
			"WHERE deleted=0"
		][
			rejoin [
				"WHERE project=" session/content/project-id
				" AND deleted=0"
			]
		]
		" ORDER BY id DESC"
		
	]
]

enum-categories: does [
	do-sql/flat 'bugs rejoin [
		"SELECT id,label FROM categories "
		either session/content/project-id = 1 [""][
			rejoin [
				"WHERE project=" session/content/project-id
				" AND deleted=0"
			]
		]
		" ORDER BY position"
	]
]

get-last-id: does [
	to integer! first do-sql/flat 'bugs "SELECT LAST_INSERT_ID()"
]

add-ticket: func [spec [block!] /local id][
	do-sql 'bugs [
		"INSERT INTO tickets VALUES (NULL,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, NULL)"
		session/content/project-id ;-- project		
		spec/summary			;-- brief		
		spec/desc				;-- description	
		spec/code				;-- code		
		any [spec/version 1]	;-- version	
		0						;-- fixedin
		any [spec/cat 1]		;-- category
		spec/severity			;-- severity	
		1						;-- status		
		1						;-- resolution	
		spec/priority			;-- priority
		1	;spec/reproduce			;-- reproduce
		spec/type				;-- type
		spec/platform			;-- platform
		0						;-- comments
		session/content/user-id	;-- user		
		now						;-- created		
		now						;-- modified
	]
	id: get-last-id
	add-log id 'added 'ticket
	id
]

update-ticket: func [spec [block!]][
	do-sql 'bugs [ {
		UPDATE tickets SET
			brief=?,
			description=?,
			code=?,
			version=?,
			fixedin=?,
			category=?,
			severity=?,
			status=?,
			priority=?,
			type=?,
			platform=?,
			modified=?
		WHERE id=?
	}
		spec/summary		
		spec/description
		spec/code		
		spec/version	
		spec/fixedin
		spec/category
		spec/severity
		spec/status	
		spec/priority
		spec/type
		spec/platform
		now	
		spec/id
	]
]

update-closed-date: func [spec [block!] new [integer!]][
	do-sql 'bugs [
		"UPDATE tickets SET closed=? WHERE id=?"
		either find [6 9 10] new [now][none]
		spec/id
	]
]

select-tickets: func [
	spec [block!] 
	/count
	/id-only
	/cursor 
		cid [integer!]
	/range
		begin [integer!]
		end	  [integer!]
	/local 
		all-projects? admin? pid user fields tables list prjs
		ofields column paging value sql s cond
][
	all-projects?: 1 = pid: session/content/project-id
	admin?: session/content/user-role = 'admin 
	user: session/content/user-id
	
	fields: case [
		count	[" COUNT(DISTINCT tickets.id) "]
		cursor	[" tickets.id "]
		id-only	[" tickets.id "]
		true	[
			{   tickets.id,
				tickets.comments,
				types.label,
				severities.label,
				statuses.label,
				tickets.modified,
				tickets.brief,
				tickets.status,
				tickets.severity,
				priorities.label,
				users.login
			}
		]
	]
	
	tables: "severities, statuses, priorities, types, users, tickets"
	
	list: copy {
		tickets.severity = severities.id
		AND tickets.status = statuses.id 
		AND tickets.priority = priorities.id 
		AND tickets.type = types.id
		AND tickets.user = users.id
	}
	either not all-projects? [
		repend list [" AND tickets.project =" pid]
	][
		if not admin? [
			prjs: remove extract enum-projects/public 2
			if user [
				prjs: union prjs do-sql/flat 'bugs join
					"SELECT rights.project FROM rights WHERE rights.user =" user
			]
			if not empty? prjs [
				insert tail list " AND tickets.project IN ("
				foreach prj prjs [
					insert tail list prj
					insert tail list #","
				]
				change back tail list ") "
			]
		]
	]
	
	if spec/find [
		if all [string? spec/text not empty? trim spec/text][
			if find [1 4 6] spec/fields [
				tables: join tables " LEFT JOIN comments ON tickets.id = comments.ticket"			
			]
			foreach w parse spec/text "" [
				value: sql-escape copy w
				unless cond: select [
					1 [
						" AND (tickets.brief LIKE '%" value "%'"
						" OR tickets.description LIKE '%" value "%' "
						" OR comments.comment LIKE '%" value "%' "
						" OR users.login LIKE '%" value "%') "
					]
					4 [
						" AND comments.comment LIKE '%" value "%' "
					]
					5 [
						" AND users.login LIKE '%" value "%' "
					]
					6 [
						" AND comments.user = cmtuser.id "
						" AND cmtuser.login LIKE '%" value "%' "
					]
				] spec/fields [
					cond: [
						" AND tickets." select [2 "brief" 3 "description"] spec/fields
						" LIKE '%" value "%' "
					]
				]
				repend list cond
			]
			if find [1 6] spec/fields [			;-- ugly, but efficient table relation changing
			;	replace list "AND tickets.user" "AND comments.user"
				tables: join tables " , users AS cmtuser"		
			]
		]
	]
	
	if any [spec/apply spec/preset][
	
		if spec/preset [apply-filter spec]
		
		if positive? any [spec/type 0][
			repend list [" AND tickets.type =" spec/type]
		]
		if positive? any [spec/cat 0][
			repend list [" AND tickets.category =" spec/cat]
		]
		if positive? any [spec/severity 0][
			repend list [" AND tickets.severity =" spec/severity]
		]
		if positive? any [spec/status 0][
			repend list [" AND tickets.status =" spec/status]
		]
		either block? spec/hstatus [
			s: make string! 8
			foreach v spec/hstatus [
				insert tail s v
				insert tail s #","
			]
			remove back tail s
			repend list [" AND tickets.status NOT IN (" s ")"]
		][
			if positive? any [spec/hstatus 0][
				repend list [" AND tickets.status <=" spec/hstatus]
			]
		]
		if positive? any [spec/priority 0][
			repend list [" AND tickets.priority =" spec/priority]
		]
		if all [
			session/content/user-id
			positive? any [spec/user 0]
		][
			repend list [" AND tickets.user =" session/content/user-id]
		]
	]
	
	ofields: [
		"tickets.id"
		"tickets.comments"
		"types.label"
		"tickets.severity"
		"tickets.status"
		"tickets.priority"
		"tickets.user"
		"tickets.modified"
		"tickets.brief"
		"users.login"
	]
	column: join 
		pick ofields min length? ofields abs spec/orderby 
		pick [" DESC " " ASC "] positive? spec/orderby
	
	paging: ""
	if not count [
		paging: rejoin [
			" LIMIT "
			either cursor [
				any [all [cid <= 1 0] cid - 2]
			][
				either range [begin][
					spec/results * (spec/page - 1)
				]
			]
			#","
			either cursor [3][either range [end - begin][spec/results]]
		]
	]
	
	sql: reform [
		"SELECT DISTINCT " fields
		"FROM" tables
		"WHERE" list
		"ORDER BY" column
		 paging
	]
	either any [cursor id-only][do-sql/flat 'bugs sql][do-sql 'bugs sql]
]

get-ticket: func [id [integer!] /local res fixedin][
	res: do-sql/flat 'bugs [ {
		SELECT 
			tickets.brief,
			tickets.description,
			tickets.code,
			versions.label,
			severities.label,
			statuses.label,
		    resolutions.label,
		    priorities.label,
		 	types.label,
			platforms.label,		    
		    tickets.created,
		    tickets.modified,
		    users.login,
		    categories.label,
		    reproduces.label,
		    projects.private,
		    tickets.project,
		    tickets.severity,
		    tickets.status,
		    tickets.fixedin,
		    projects.name
		FROM 
			tickets, 		severities,
			statuses, 		priorities,
			resolutions,	users,
			versions,		categories,
			reproduces,		types,
			platforms,		projects
		WHERE
			tickets.severity = severities.id
			AND tickets.status = statuses.id
			AND tickets.resolution = resolutions.id
			AND tickets.priority = priorities.id
			AND tickets.user = users.id
			AND tickets.version = versions.id
			AND tickets.category = categories.id
			AND tickets.reproduce = reproduces.id
			AND tickets.type = types.id
			AND tickets.platform = platforms.id
			AND tickets.project = projects.id
			AND tickets.id = ?}
		id
	]	
	if all [not empty? res fixedin: pick tail res -2][
		change back back tail res do-sql/flat 'bugs join 
			"SELECT label FROM versions WHERE id=" 
			fixedin
	]
	res
]

check-ticket-id: func [id [integer!]][
	not empty? do-sql/flat 'bugs either session/content/project-id > 1 [
		[ {
			SELECT tickets.id FROM tickets
			WHERE 
				tickets.project=?	
				AND tickets.id=?}
			session/content/project-id
			id
		]
	][
		join "SELECT tickets.id FROM tickets WHERE tickets.id=" id
	]
]

get-raw-ticket: func [id [integer!]][
	do-sql/flat 'bugs rejoin [ {
		SELECT tickets.*, users.login FROM tickets, users
		WHERE
			tickets.user = users.id
			AND tickets.id = } id
		]
]

list-fixed-tickets: func [vid [integer!]][
	do-sql 'bugs [ {
		SELECT 
			tickets.id,
			categories.label,
			tickets.brief,
			users.login
		FROM
			tickets, categories, users
		WHERE
			tickets.category = categories.id
			AND tickets.fixedin = ?
			AND tickets.user = users.id
			AND tickets.status > 5
			AND tickets.project = ?
		ORDER BY tickets.category DESC
		}
		vid
		session/content/project-id
	]
]

delete-ticket: func [id [integer!]][
	do-sql 'bugs join "DELETE FROM tickets WHERE id=" id
	do-sql 'bugs join "DELETE FROM comments WHERE ticket=" id
	do-sql 'bugs join "DELETE FROM logs WHERE ticket=" id
]

move-ticket: func [
	ticket [block!] prj-id [integer!]
	/local new-version new-cat id old-ver old-fixed old-cat old-prj new-prj
][
	id: ticket/1
	if empty? new-version: get-versions/only prj-id [new-version: reduce [none #"-"]]
	if empty? new-cat: get-categories/only prj-id [new-cat: reduce [none #"-"]]
	old-ver:   select enum-versions   ticket/6
	old-fixed: select enum-versions   ticket/7
	old-cat:   select enum-categories ticket/8
	old-prj:   select enum-projects	  ticket/2
	new-prj:   select enum-projects   prj-id
	
	if old-fixed [
		add-log/msg id 'modified 'fixedin  reform [old-fixed "=> -"]
	]
	add-log/msg id 'modified 'version  reform [old-ver "=>" new-version/2]
	add-log/msg id 'modified 'category reform [old-cat "=>" new-cat/2]
	add-log/msg id 'moved    'ticket   rejoin [{"} old-prj {" => "} new-prj {"}]
	
	do-sql 'bugs [
		"UPDATE tickets SET project=?, version=?, fixedin=0, category=? WHERE id=?"
		prj-id
		any [new-version/1 1]
		any [new-cat/1 1]
		id
	]
]

add-project: func [spec [block!]][
	db-cache/invalid 'bugs [
		projects
		priv-proj
		pub-proj
	]
	do-sql 'bugs [
		"INSERT INTO projects VALUES (NULL,?,?,?,0)"
		spec/name		;-- name		
		spec/desc		;-- description
		spec/priv		;-- private
	]
]

update-project: func [spec [block!]][
	db-cache/invalid 'bugs [
		projects
		priv-proj
		pub-proj
	]	
	do-sql 'bugs [
		"UPDATE projects SET name=?,description=?,private=? WHERE id=?"
		trim spec/name	;-- name		
		spec/desc		;-- description
		spec/priv		;-- private
		spec/id
	]
]

get-project: func [id [integer!]][
	do-sql/flat 'bugs join "SELECT name,description,private FROM projects WHERE id=" id
]

get-stats-by: func [type [word!] /local tbl field ord][
	set [tbl field ord] select [
		status		["statuses" "status" "ASC"]
		priority	["priorities" "priority" "DESC"]
		severity	["severities" "severity" "DESC"]
	] type
	do-sql/flat 'bugs rejoin [
		"SELECT DISTINCT "tbl".label, COUNT(tickets.id) "
		"FROM tickets RIGHT JOIN "tbl" ON tickets."field"="tbl".id "
		either session/content/project-id <> 1 [
			join " AND tickets.project=" session/content/project-id
		][""]
		" GROUP BY "tbl".label ORDER BY "tbl".id " ord
	]
]

set 'get-stockpile-month func [dt [date!] /local sql][		; global for reaching from helper.r
	sql: {
		SELECT
			COUNT(DISTINCT id)
		FROM 
			tickets
		WHERE
			created<=?
			AND (closed is NULL OR closed>?)
	}
	if session/content/project-id <> 1 [
		sql: join sql [" AND project=" session/content/project-id]
	]
	do-sql/flat 'bugs reduce [sql dt dt]
]

get-stockpile-evo: has [sql1 sql2][
	sql1: rejoin [ {
		SELECT
			STR_TO_DATE(CONCAT(EXTRACT(YEAR_MONTH FROM created),'01'),'%Y%m%d'),
			COUNT(id)
		FROM 
			tickets
		}
		either session/content/project-id <> 1 [
			rejoin [" WHERE project=" session/content/project-id]
		][""]
		{ GROUP BY
			YEAR(created),MONTH(created)}
	]
	sql2: rejoin [ {
		SELECT
			STR_TO_DATE(CONCAT(EXTRACT(YEAR_MONTH FROM logs.date),'01'),'%Y%m%d'),
			COUNT(DISTINCT tickets.id)
		FROM 
			tickets, logs
		WHERE
			tickets.id = logs.ticket
			AND logs.field = 8
			AND logs.new IN (6,9,10)
		}
		either session/content/project-id <> 1 [
			rejoin [" AND project=" session/content/project-id]
		][""]
		{ GROUP BY
			YEAR(logs.date),MONTH(logs.date)}
	]
	reduce [
		do-sql/flat 'bugs sql1
		do-sql/flat 'bugs sql2
	]

]

access-project?: func [prj-id [integer!] user-id [integer!]][
	not empty? do-sql/flat 'bugs [
		"SELECT id FROM rights WHERE user=? AND project=?"
		user-id
		prj-id
	]
]

access-level?: func [prj-id [integer!] user-id [integer!]][
	either empty? res: do-sql/flat 'bugs [ {
		SELECT
			roles.label
		FROM
			rights, roles
		WHERE 
			rights.role = roles.id
			AND user=? AND project=?
		}
		user-id
		prj-id
	][none][first res]
]

list-granted-projects: func [user-id [integer!]][
	do-sql/flat 'bugs [ {
		SELECT
			rights.project,
			projects.name 
		FROM
			rights, projects
		WHERE
			rights.project = projects.id
			AND user=?} user-id
	]
]

add-user: func [spec [block!] vkey [string!]][
	do-sql 'bugs [
		"INSERT INTO users VALUES (NULL,?,?,?,?,?,?,0,?,NULL)"
		spec/login								;-- login
		encode-pass spec/pass 					;-- pasw
		spec/email								;-- email
		vkey									;-- vkey
		none									;-- vdate
		2										;-- role (default=reporter)
		now										;-- created
	]
]

import-user: func [spec [block!]][
	do-sql 'bugs [
		"INSERT INTO users VALUES (NULL,?,?,?,?,?,?,0,?,NULL)"
		spec/2									;-- login
		spec/3				 					;-- pasw
		spec/4									;-- email
		spec/5									;-- vkey
		now										;-- vdate
		2										;-- role (default=reporter)
		now										;-- created
	]
]

delete-user: func [id [integer!]][
	do-sql 'bugs join "UPDATE users SET deleted=1 WHERE id > 1 AND id=" id
]	

get-user: func [id [integer!]][
	do-sql/flat 'bugs join {
		SELECT 
			login,email,vdate,roles.label,created,vkey,role
		FROM 
			users,roles
		WHERE
			users.role = roles.id	
			AND users.id=} id
]

check-user: func [spec [block!] /local res][
	if empty? res: do-sql/flat 'bugs [
		"SELECT vkey FROM users WHERE login=? AND email=?"
		 spec/login
		 form spec/email
	][
		return "Unknown user"
	]
	res
]

exists-user?: func [login [string!] /local res][
	res: do-sql/flat 'bugs [
		"SELECT id FROM users WHERE login=?"
		login
	]
	all [res res/1]
]

identify-user: func [spec [block!] /local res][
	if empty? do-sql 'bugs [
		"SELECT id FROM users WHERE deleted=0 AND login=?"
		 spec/login
	][
		return "Unknown user"
	]
	if empty? res: do-sql/flat 'bugs [
		{SELECT users.id,roles.label,users.vdate FROM users,roles
		 WHERE users.role=roles.id AND deleted=0 AND login=? AND pasw=?}
		spec/login
		encode-pass spec/pass
	][
		return "Wrong password"
	]
	if not res/3 [
		return "Account not yet activated"
	]
	res
]

identify-remote-user: func [db [url!] spec [block!] /local res][
	db: open db
	if empty? send-sql db [
		"SELECT id FROM users WHERE deleted=0 AND login=?"
		 spec/login
	][
		close db	
		return "Unknown user"
	]
	if empty? res: send-sql/flat db [
		"SELECT * FROM users WHERE deleted=0 AND login=? AND pasw=?"
		spec/login
		encode-pass spec/pass
	][
		close db
		return "Wrong password"
	]
	if not res/3 [
		close db
		return "Account not yet activated"
	]
	close db
	res
]

validate-user: func [spec [block!] /update /local res][
	either empty? res: do-sql/flat 'bugs [
		"SELECT id FROM users WHERE login=? and vkey=?"
		spec/id
		spec/key
	][
		false
	][
		if update [
			do-sql 'bugs [
				"UPDATE users SET vdate=NOW() WHERE id=?"
				first res
			]
		]
		true
	]
]

force-validation: func [id [integer!]][
	do-sql 'bugs join "UPDATE users SET vdate=NOW() WHERE id=" id
]

update-user-pass: func [spec [block!]][
	do-sql/flat 'bugs [
		"UPDATE users SET pasw=? WHERE id=?"
		encode-pass spec/pass
		session/content/user-id
	]	
]

change-user-role: func [spec [block!]][
	do-sql/flat 'bugs [
		"UPDATE users SET role=? WHERE id > 1 AND id=?"
		spec/urole
		spec/id
	]	
]

reset-pass: func [spec [block!]][
	do-sql/flat 'bugs [
		"UPDATE users SET pasw=? WHERE login=?"
		"084E0343A0486FF05530DF6C705C8BB4"		; "guest"
		spec/id
	]	
]

add-right: func [spec [block!]][
	do-sql 'bugs [
		"INSERT INTO rights VALUES (NULL,?,?,?)"
		spec/id			;-- user		
		spec/prj		;-- project
		spec/role		;-- role
	]
]

get-rights: func [user-id [integer!]][
	do-sql 'bugs join {
		SELECT
			rights.id, rights.project, projects.name, roles.label
		FROM
			rights, projects, roles
		WHERE
			rights.project = projects.id
			AND rights.role = roles.id
			AND projects.private = 1
			AND rights.user = } user-id
]

remove-right: func [id [integer!]][
	do-sql 'bugs join "DELETE FROM rights WHERE id=" id
]

get-versions: func [id [integer!] /only /local sql][
	sql: "SELECT id,label FROM versions WHERE deleted=0 AND project=? ORDER BY id"
	if only [sql: join sql " DESC LIMIT 1"]
	do-sql/flat 'bugs reduce [sql id]
]

add-version: func [spec [block!]][
	do-sql 'bugs [
		"INSERT INTO versions VALUES (NULL,?,?,0)"
		spec/id			;-- project
		spec/vlabel		;-- label
	]
]

remove-version: func [id [integer!] /local res][
	res: do-sql/flat 'bugs [
		"SELECT COUNT(id) FROM tickets WHERE version=? OR fixedin=?" id id
	]
	either zero? to-integer first res [
		do-sql 'bugs join "DELETE FROM versions WHERE id=" id
	][
		do-sql 'bugs join "UPDATE versions SET deleted=1 WHERE id=" id
	]
]

get-categories: func [id [integer!] /only /local sql][
	sql: "SELECT id,label FROM categories WHERE deleted=0 AND project=? ORDER BY position"
	if only [sql: join sql " LIMIT 1"]
	do-sql 'bugs reduce [sql id]
]

get-first-category: func [prj [integer!]][
	do-sql 'bugs [
		"SELECT id,label FROM categories WHERE deleted=0 AND project=? ORDER BY position LIMIT 1"
		prj
	]
]

add-category: func [spec [block!] /local res][
	res: do-sql/flat 'bugs "SELECT MAX(position) FROM categories"
	res: either empty? res [1][1 + first res]
	do-sql 'bugs [
		"INSERT INTO categories VALUES (NULL,?,?,0,?)"
		spec/id			;-- project
		spec/clabel		;-- label
		res
	]
]

remove-category: func [id [integer!] /local res][
	res: do-sql/flat 'bugs [
		"SELECT COUNT(id) FROM tickets WHERE category=?" id
	]
	either zero? to-integer first res [
		do-sql 'bugs join "DELETE FROM categories WHERE id=" id
	][
		do-sql 'bugs join "UPDATE categories SET deleted=1 WHERE id=" id
	]
]

swap-category-positions: func [cat1 [integer!] cat2 [integer!] /local one two][
	if any [zero? cat1 zero? cat2][exit]
	
	one: first do-sql/flat 'bugs join "SELECT position FROM categories WHERE id=" cat1
	two: first do-sql/flat 'bugs join "SELECT position FROM categories WHERE id=" cat2
	do-sql 'bugs ["UPDATE categories SET position=? WHERE id=?" one cat2]
	do-sql 'bugs ["UPDATE categories SET position=? WHERE id=?" two cat1]
]

add-comment: func [spec [block!] /local id][
	do-sql 'bugs [
		"INSERT INTO comments VALUES (NULL,?,?,?,?)"
		spec/id
		spec/cmt
		session/content/user-id
		now
	]
	id: get-last-id
	do-sql 'bugs [
		"UPDATE tickets SET comments = comments + 1, modified=NOW() WHERE id=?"
		spec/id
	]
	add-log/id spec/id 'added 'comment id	
]

list-comments: func [id [integer!] /no-flat /local sql][
	sql: {
		SELECT 
			comments.id,
			users.login,
			comments.created,
			comments.comment 
		FROM comments, users
		WHERE 
			comments.user = users.id
			AND comments.ticket=?
		ORDER BY comments.id ASC}
	
	either no-flat [
		do-sql 'bugs reduce [sql id]
	][
		do-sql/flat 'bugs reduce [sql	id]
	]
]

remove-comment: func [spec [block!]][
	do-sql 'bugs ["DELETE FROM comments WHERE id=?" spec/cid]
	do-sql 'bugs ["UPDATE tickets SET comments = comments - 1 WHERE id=?" spec/id]
	add-log/id spec/id 'removed 'comment spec/cid
]

update-comment: func [spec [block!]][
	do-sql 'bugs [
		"UPDATE comments SET comment=? WHERE id=?"
		dehex spec/cmt
		spec/cid
	]
	add-log/id spec/id 'modified 'comment spec/cid
]

touched-by-others?: func [id [integer!]][
	to integer! first do-sql/flat 'bugs [
		"SELECT IFNULL(COUNT(logs.id), 0) FROM logs WHERE logs.user<>? AND logs.ticket=?"
		session/content/user-name
		id
	]
]

list-logs: func [id [integer!]][
	do-sql/flat 'bugs [ {
		SELECT date, user, action, field, opt_id, old, new, msg
		FROM logs WHERE ticket=?
		ORDER BY date DESC
		} id
	]
]

add-log: func [
	ticket [integer!]
	action [word!]
	field [word!]
	/id opt-id [integer!]
	/old old-value [integer!]
	/new new-value [integer!]
	/msg txt [string!]
][
	do-sql 'bugs [
		"INSERT INTO logs VALUES (NULL,?,?,?,?,?,?,?,?,?)"
		ticket
		now
		session/content/user-name
		history/encode action
		history/encode field
		opt-id
		old-value
		new-value
		txt
	]
]

select-logs: func [id [integer!] /ticket /local tables conds][
	tables: "logs"
	conds: make string! 16
	
	either ticket [
		repend conds [" logs.ticket=" id]
	][
		if id > 1 [
			tables: "logs, tickets"
			repend conds [" logs.ticket = tickets.id AND tickets.project=" id " AND"]
		]
		append conds " action IN (1,2,3,19) AND field IN (8,15,16)"
	]
	do-sql/flat 'bugs reform [
		"SELECT logs.* FROM" tables 
		"WHERE" conds
		"ORDER BY logs.id DESC LIMIT 100"
	]
]

get-user-prefs: func [id [integer!] /local proto res][
	proto: [
		version	1
		tickets-color-mode	line		; others: column, none
		tickets-alt-color	#EEE		; if mode <> line
		my-project			1			; "All Project"
		my-filter			#[none]
		my-colors			[255.0.0]	; colors list for status
	]
	res: do-sql/flat 'bugs join "SELECT data FROM prefs WHERE user=" id
	either empty? res [
		res: mold/flat/all new-line/all proto off
		do-sql/flat 'bugs ["INSERT INTO prefs VALUES(NULL,?,?)" id res]
		copy/deep proto
	][
		load first res
	]
]

update-user-defaults: does [
	session/content/prefs/my-project: session/content/project-id
	session/content/prefs/my-filter: copy session/content/query
	do-sql/flat 'bugs [
		"UPDATE prefs SET data=? WHERE user=?"
		mold/flat/all new-line/all session/content/prefs off
		session/content/user-id
	]
]

add-file: func [ticket [integer!] original [string!] new [file!]][
	do-sql 'bugs [
		"INSERT INTO files VALUE(NULL,?,?,?,NOW(),?)"
		ticket
		form original
		new
		session/content/user-id
	]
]

list-files: func [id [integer!]][
	do-sql 'bugs [
		"SELECT name, file FROM files WHERE ticket=? ORDER BY created" 
		id
	]
]

get-file-name: func [code [string!] /local res][
	res: do-sql/flat 'bugs ["SELECT name FROM files WHERE file=?" code]
	all [not empty? res res/1]
]

remove-file: func [ticket [integer!] id [string! file!]][
	do-sql 'bugs [
		"DELETE FROM files WHERE ticket=? AND file=?" 
		ticket
		id
	]
]