REBOL [
	Purpose: "RSP environement init code"
]

on-application-start: does [
	do %private/helper.r
	do %private/db-abstract.r
	do %private/access-control.r
]

on-application-end: does []

on-database-init: does [
	define-cached-queries
]

on-session-start: has [list][
	session/add 'project-id 1
	session/add 'user-id 	none
	session/add 'user-name	none
	session/add 'user-role	'viewer
	session/add 'user-prj-role none
	session/add 'prefs	none
	session/add 'files	none
	session/add 'query copy [
		preset		"search"
		filter		2
		text		#[none]
		fields		2
		tid			#[none]
		type		0
		severity	0
		user		0
		status		0
		hstatus		0
		priority	0
		results		25
		action		search
		page		1
		orderby 	1
		version		#[none]
		fixedin		#[none]
		cat			#[none]
		resolv		#[none]
		find		#[none]
		apply		#[none]
	]
]

on-session-end: does []

on-page-start: does [
	filter-access
]

on-page-end: does []
