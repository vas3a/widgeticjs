wl = window.location
unless wl.origin
	wl.origin = wl.protocol + "//" + wl.hostname + (if wl.port then ':' + wl.port else '')

parse = require './detect/parse'

domain = window.widgeticOptions?.domain || 'widgetic.com'
o = "?lo=#{encodeURIComponent wl.origin}"
config ={
	proxy:"https://#{domain}/sdk/proxy.html#{o}#proxy",
	popup:"https://#{domain}/sdk/proxy.html#{o}#popup",
	auth:"https://#{domain}/oauth/v2/auth",
	composition:"https://#{domain}/api/v2/compositions/{id}/embed.html#{o}",
	widget:"https://#{domain}/api/v2/widgets/{id}/embed.html#{o}",
	editor:"https://#{domain}/api/v2/editor.html#{o}",
	api:"/api/v2/",
	domain: "https://#{domain}",
	lo: decodeURIComponent parse(wl).queryKey.lo or wl.origin#listen to origin
}
module.exports = config