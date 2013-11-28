parse = require './parse'
json  = require 'json3'
win   = window

detect = (url)->
	return if win.parent and win.parent is win and !win.opener

	parsed 		= parse url
	hash 		= parsed.hash
	hashKey	 	= parsed.hashKey
	query  		= parsed.query
	queryKey 	= parsed.queryKey
	proxy 		= hash is 'proxy'

	return unless query or hashKey.access_token or proxy
	t  = if proxy then 'i' else 'o'
	d = if hash then (unless proxy then hashKey) else queryKey
	(win.opener or win.parent).postMessage json.stringify({d,t}),'*'
	
detect.parse = parse
module.exports = detect