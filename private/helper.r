REBOL []

random/seed now/time/precise 

zeropad: func [value n][
	head insert/dup value: form value #"0" n - length? value
]

ceil: func [n [number!]][
	if integer? n [return n]
	to integer! n + 0.99999999999999
]

mark: context [
	selected: func [key field [word!] default][
		if key = any [request/content/:field :default][prin " selected "]
	]
	
	error: func [field [word!]][
		if find invalid :field [prin {class="error"}]
	]
]

encode-pass: func [pass [string!]][
	enbase/base checksum/method pass 'md5 16
]

pre-chars: charset "^/^-"
pre-encode: func [data [string!] /local s][
	data: convert data [pre-chars][
		either value = "^/" [
			"<br/>"
		][
			"&nbsp;&nbsp;&nbsp;&nbsp;"
		]
	]
	parse/all data [				;-- remove extra <br/> encodings only
		any [
			"<pre" any [
				s: <br/> (s: remove/part s 5) :s
				| </pre> break
				| skip
			]
			| skip
		]
	]
	data
]

digits: charset "0123456789"
not-ws: complement charset "^/^-^M <"
activate-links: func [data [string!] /local s e link][
	parse/all data [
		any [
			"&#"
			| s: #"#" some digits e: (
				change/part s link: rejoin [
					{<a href="ticket.rsp?id=} next link: copy/part s e {">}
					link 
					"</a>"
				] e
				s: skip s length? link
			) :s
			| s: ["http" opt "s"] "://" some not-ws e: (
				change/part s link: rejoin [
					{<a href="} link: copy/part s e {">}
					link 
					"</a>"
				] e
				s: skip s length? link
			) :s
			| skip
		]
	]
	data
]

coltitle: func [pos show? name /local current?][
	if not show? [
		prin say name
		exit
	]
	if current?: pos = abs order [
		prin {<img src="img/} 
		prin pick ["up" "down"] positive? order
		prin {.png" align="right">}
	]
	prin {<a href="view-tickets.rsp?orderby=}
	prin any [all [current? negate order] pos]
	prin {">}
	prin say name
	prin {</a>}
]

utf8-encode: func [
	"Encodes the string data to UTF-8 (from Latin-1)"
	str [any-string!] "string to encode"
	/local c h
][
	;if you remove 'copy you can change the original string
	parse/all copy str [
		any [
			h: skip ( if 127 < c: first h [
				h: change h c / 64 or 192
				insert h c and 63 or 128
			]) :h
		   skip
		]
	]
	head h
]

quotes-chars: charset {'^"}
js-encode: func [str [any-string!]][
	convert utf8-encode str [quotes-chars][head insert value #"\"]
]

export-json: func [/crunch] [
	response/set-header 'Content-Type "application/json"
]

to-epoch: func [dt [date!]][
	(dt/date - 01/01/1970) * 86400 + to integer! dt/time
]

chart-form: func [blk sep /with tot /local out][
	out: make string! 3 * length? blk
	
	foreach v blk [
		either tot [
			insert tail out to integer! 100 * either zero? tot [0][divide to integer! v tot]
		][
			insert tail out utf8-encode say v
		]
		insert tail out sep
	]
	head remove back tail out
]

chart-form-full: func [data colors labels tot /local outd outc outl i list][
	outd: make string! 3 * length? data
	outc: make string! 64
	outl: make string! 64
	
	i: 1
	foreach v data [
		unless zero? v: to integer! v [		
			insert tail outd to integer! 100 * either zero? tot [0][v / tot]
			insert tail outd #","
			
			insert tail outc colors/:i
			
			insert tail outl utf8-encode say labels/:i
			insert tail outl #"|"
		]
		i: i + 1
	]
	foreach buf list: [outd outc outl][remove back tail get buf]
	reduce list
]


adjust-scale: func [out [block!] max-val [integer!] /local f s val][
	f: pick [50 5] 50 <= (s: max-val / 5)							;-- stepping factor
	s: f * (1 + to integer! s / f)								 	;-- axis steps rounded to ceil
	unless zero? val: max-val // s [max-val: max-val - val + s]		;-- max value adjustment
	insert tail out max-val
	insert tail out s
]

prepare-stockpile: func [list [block!] /local out dt val s][
	sort/reverse/skip list/1 2
	sort/reverse/skip list/2 2
	out: array/initial 3 []
	s: 0
	
	repeat c 6 [
		dt: now/date
		dt/month: dt/month + 1 - c
		dt/day: 1
		insert out/1 join copy/part pick system/locale/months dt/month 3 [#"-" skip form dt/year 2]
		insert out/2 val: any [select list/1 dt "0"]
		if s < val: to integer! val [s: val]
		insert out/3 val: any [select list/2 dt "0"]
		if s < val: to integer! val [s: val]
	]
	adjust-scale out s
	out
]

prepare-monthly-stockpile: has [out dt val s][
	out: array/initial 2 []
	s: 0
	
	repeat c 6 [
		dt: now/date
		dt/month: dt/month + 1 - c
		dt/day: 1
		insert out/1 join copy/part pick system/locale/months dt/month 3 [#"-" skip form dt/year 2]
		dt/month: dt/month + 1
		dt/day: dt/day - 1
		insert out/2 val: get-stockpile-month dt
		if s < val: to integer! val/1 [s: val]
	]
	adjust-scale out s
	out
]

history: context [
	labels: make hash! 57
	foreach [w c][
		added		-
		removed		-
		modified	-
		summary		-
		description	-
		code		-
		severity	severities
		status		statuses
		resolution	resolv
		priority	priorities
		reproduce	reproduces
		version		-
		fixedin		-
		category	-
		comment		-
		ticket		-
		type		types
		platform	platforms
		moved		-
	][
		repend labels [w c uppercase/part form w 1]
	]
	poke labels 11 * 3 "Reproducibility"
	
	encode: func [w [word!]][
		divide 2 + index? find/skip labels w 3 3
	]
	decode: func [fid [integer!] /value vid /local w][
		say either all [
			value
			'- <> w: pick labels 3 * fid - 1 
		][
			select do-sql/flat 'bugs w vid
		][
			pick labels 3 * fid
		]
	]	
]


set 'form-time func [time [time!]][
	copy/part either time/hour < 10 [
		head insert mold time #"0"
	][
		mold time
	] 5
]

set 'to-UTC func [date [date!]][date - date/zone]

make-vkey: has [key][
	key: make string! 16
	loop 16 [append key #"@" + random 26]
	key: checksum/method key 'md5
	enbase/base key 16
]

filters-list: [
	1	"My Reports"
	2	"Most Recent Reports"
	3	"Unreviewed Submissions"
	4	"Active Priorities"
	5	"Tested"
	6	"Recent Changes"
	7	"Worst Severity"
	8	"By Submitter"
	9	"Completed"
]

enum-filters: has [out][
	either session/content/user-id [
		filters-list
	][
		skip filters-list 2
	]
]

apply-filter: func [spec [block!] /local filter][
	filter: pick [
		[orderby 8 user 1]					;-- My Tickets
		[orderby  1]						;-- Most Recent Reports
		[status  1 orderby  4]				;-- Unreviewed Submissions
		[hstatus [6 8 9 10] orderby  6]		;-- Active Priorities
		[status  9 orderby  8]				;-- Tested
		[orderby 8]							;-- Recent Changes
		[hstatus [6 8 9 10] orderby  4]		;-- Worst Severity
		[orderby -10]						;-- By Submitter
		[status  10 orderby -1]				;-- Completed
	] spec/filter
	
	foreach name [type severity status hstatus priority user orderby][
		poke find spec name 2 any [select filter name 0]
	]
]

recaptcha-verify: func [spec [block!] /local data res][
	data: rejoin [
		"privatekey=" 		recaptcha/private-key
		"&remoteip="	request/client-ip
		"&challenge="	spec/recaptcha_challenge_field
		"&response="	spec/recaptcha_response_field
	]
	res: attempt [
		read/custom http://www.google.com/recaptcha/api/verify reduce ['POST data]
	]
	to logic! all [res find/part res "true" 4]
]

get-instance-db: func [instance [string!] /local tests rule list url][
	tests: [
		url: select list 'bugs
		url: find/last url slash
		not empty? next url
		return head url
	]
	all [
		list: select cheyenne-conf/globals 'databases
		all tests
	]
	parse cheyenne-conf rule: [
		any [
			'virtual-root set name string!
			thru 'databases set list block! (
				all [
					list
					instance = trim/with copy name slash
					all tests
				]
			) | into rule | skip
		]
	]
	none
]

; ====== Email management ======

curecode-emitter: no-reply@curecode.org

send-confirmation: func [
	spec [block!] vkey [string!]
	/local url login pass template
][
	url: rejoin [
		request/headers/Host
		either request/server-port = 80 [""][join ":" request/server-port]
		request/web-app
		"/validate.rsp?id=" url-encode spec/login 
		"&key=" vkey
	]
	login: spec/login
	pass: spec/pass
	template: read join locale/get-path %email-activation.tpl
	replace template "$url" url
	replace template "$login" login
	replace template "$pass" pass
	
	send-email compose [
		from: 	 (curecode-emitter)
		to:   	 (to-email spec/email)
		subject: (rejoin ["[" request/config/locals/name "] " say "Account activation"])
	] template
]

send-reset-URL: func [
	spec [block!] vkey [string!]
	/local url template
][
	url: rejoin [
		request/headers/Host
		either request/server-port = 80 [""][join ":" request/server-port]
		request/web-app
		"/reset.rsp?id=" url-encode spec/login 
		"&key=" vkey
	]
	template: read join locale/get-path %email-pass-reset.tpl
	replace template "$url" url
	
	send-email compose [
		from: 	 (curecode-emitter)
		to:   	 (to-email spec/email)
		subject: (rejoin ["[" request/config/locals/name "] " say "Password reset confirmation"])
	] template
]
