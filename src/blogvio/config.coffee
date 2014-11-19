parse = require './detect/parse'

deriveScriptElement = ->
	id = "blogvio_test_src"
	document.write "<script id='#{id}'></script>"
	dummyScript = document.getElementById id
	element 	= dummyScript.previousSibling
	element=element.previousSibling if element.nodeName =='STYLE'
	dummyScript.parentNode.removeChild dummyScript
	element

script 	= deriveScriptElement()
url 	= parse script.src
domain 	= url.hashKey['domain'] || 'widgetic.com'
wl      = window.location
o = "?lo=#{encodeURIComponent wl.origin}"
config ={
	proxy:"//#{domain}/sdk/proxy.html#{o}#proxy",
	popup:"//#{domain}/sdk/proxy.html#{o}#popup",
	auth:"//#{domain}/oauth/v2/auth",
	composition:"//#{domain}/api/v2/compositions/{id}/embed.html#{o}",
	widget:"//#{domain}/api/v2/widgets/{id}/embed.html#{o}",
	editor:"//#{domain}/api/v2/editor.html#{o}",
	api:"/api/v2/",
	domain: "#{wl.protocol}//#{domain}",
	lo: decodeURIComponent parse(wl).queryKey.lo or wl.origin#listen to origin
}
module.exports = config