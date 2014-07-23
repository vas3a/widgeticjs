parse = require './parse'
json  = require 'json3'
win   = window

detect = (url)->
	return if win.parent and win.parent is win and !win.opener

	parsed      = parse url
	hash        = parsed.hash
	hashKey     = parsed.hashKey
	query       = parsed.query
	queryKey    = parsed.queryKey

	isProxy     = hash is 'proxy'
	isPopup     = hashKey.hasOwnProperty('popup')
	isOauth     = !isProxy and !isPopup

	return unless query or hashKey.access_token or isProxy or isPopup

	type = 'o'
	type = 'i' if isProxy
	type = 'p' if isPopup

	data = if hash then hashKey else queryKey

	(win.opener or win.parent).postMessage json.stringify({ d: data, t: type }),'*'
	
detect.parse = parse
module.exports = detect