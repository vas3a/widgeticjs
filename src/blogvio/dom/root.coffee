css="#blogvio-root{position:absolute;top:-1000px;left:-1000px;width:0px;height:0px;visibility:hidden;z-index:-1}
#blogvio-root iframe{width:0px;height:0px}"

config 	= require '../config'
event 	= require '../utils/event'
api 	= require '../api/index'
steps   = api.queue.steps

aye 	= require 'aye'

Root = ->
	body = document.getElementsByTagName('body')[0]
	head = document.getElementsByTagName('head')[0]

	body.appendChild @el = document.createElement 'div'
	@el.id = "blogvio-root"
	
	head.appendChild style = document.createElement('style')
	style.textContent = css

	@

Root.prototype.createProxy = ->
	if steps.init
		proxy 	= document.createElement 'iframe'
		@el.appendChild proxy
		fail  = ->
			Root._done = null
			clearTimeout timeout
			console.error 'Could not initialize iframe'

		timeout = setTimeout  fail,10000

		Root._done = ->
			api.setProxy (message)->proxy.contentWindow.postMessage message,'*'
			
			console.log "SDK initialized"
			clearTimeout timeout
			steps.init()
			Root._done = steps.init = null
			
		proxy.setAttribute 'src', config.proxy

	@

Root.connect = ->
	Root._done?()

module.exports = Root