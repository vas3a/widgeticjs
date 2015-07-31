wl = window.location
unless wl.origin
	wl.origin = wl.protocol + "//" + wl.hostname + (if wl.port then ':' + wl.port else '')

parse = require './detect/parse'

domain = window.widgeticOptions?.domain || 'widgetic.com'
o = "?lo=#{encodeURIComponent wl.origin}"
protocol = if window.widgeticOptions?.secure == false then 'http' else 'https'

# allows using local.widgetic.com/app_dev.php as domain
parsedDomain = parse(domain)
host = parsedDomain.host + (if parsedDomain.port then ':' + parsedDomain.port else '')

config ={
	proxy:"#{protocol}://#{host}/sdk/proxy.html#{o}#proxy",
	popup:"#{protocol}://#{host}/sdk/proxy.html#{o}#popup",
	auth:"#{protocol}://#{domain}/oauth/v2/auth",
	composition:"#{protocol}://#{domain}/api/v2/compositions/{id}/embed.html#{o}",
	widget:"#{protocol}://#{domain}/api/v2/widgets/{id}/embed.html#{o}",
	editor:"#{protocol}://#{domain}/api/v2/editor.html#{o}",
	api:"/api/v2/",
	domain: "https://#{host}",
	lo: decodeURIComponent parse(wl).queryKey.lo or wl.origin#listen to origin
}
module.exports = config