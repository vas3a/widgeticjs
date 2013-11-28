parse = (str) ->
	o = parse.options
	m = o.parser[(if o.strictMode then "strict" else "loose")].exec(str)
	uri = {}
	i = 14
	uri[o.key[i]] = m[i] or ""  while i--
	uri[o.q.name] = {}
	uri[o.key[12]].replace o.q.parser, ($0, $1, $2) ->
		uri[o.q.name][$1] = $2  if $1

	uri[o.h.name] = {}
	uri[o.key[13]].replace o.h.parser, ($0, $1, $2) ->
		uri[o.h.name][$1] = $2  if $1
	uri
parse.options =
	strictMode: false
	key: ["source", "protocol", "authority", "userInfo", "user", "password", "host", "port", "relative", "path", "directory", "file", "query", "hash"]
	q:
		name: "queryKey"
		parser: /(?:^|&)([^&=]*)=?([^&]*)/g
	h:
		name: "hashKey"
		parser: /(?:^|&)([^&=]*)=?([^&]*)/g

	parser:
		strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/
		loose: /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
module.exports = parse