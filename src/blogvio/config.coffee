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
domain 	= url.hashKey['domain'] || 'blogvio.com'
config ={
	proxy:"//#{domain}/sdk/proxy.html#proxy",
	auth:"//#{domain}/oauth/v2/auth",
	composition:"//#{domain}/api/v2/compositions/{id}/embed",
	widget:"//#{domain}/api/v2/widgets/{id}/embed",
	api:"/api/v2/"
}
module.exports = config