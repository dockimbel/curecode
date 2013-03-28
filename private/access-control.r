REBOL []

comment {
	4 admin -> all
	3 developer -> !manager, !not-other-projects
	2 reporter -> !manager, !not-other-projects, !edit-other-ticket, !delete-ticket
	1 viewer -> !manager, !edit-ticket, !delete-ticket, !add-comment
}

deny-access: does [
	;response/redirect join request/web-app "/denied.html"
	response/redirect join request/web-app "/index.rsp"
]

filter-access: does [
	if not switch session/content/user-role [
		viewer [
			find [
				"index.rsp"
				"register.rsp"
				"view-tickets.rsp"
				"ticket.rsp"
				"validate.rsp"
				"set-project.rsp"
				"reset-pass.rsp"
				"reset.rsp"
				"captcha.rsp"
				"api.rsp"
				"attached.rsp"
				"get-file.rsp"
				"feed.rsp"
			] request/parsed/target
		]
		reporter [
			not find request/parsed/path "manage"	
		]
		developer [
			not find request/parsed/path "manage"	
		]
		admin [
			yes
		]
	][	
		deny-access
	]
]