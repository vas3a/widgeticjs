css="#widgetic-root{position:absolute;top:-1000px;left:-1000px;width:0px;height:0px;visibility:hidden;z-index:-1}
#widgetic-root iframe{width:0px;height:0px}
iframe.widgetic-composition {border: none;width: 100%;height: 100%;}
iframe.widgetic-editor {width: 490px; height: 565px; border:none;overflow:hidden}
"

config 	= require '../config'
event 	= require '../utils/event'
api 	= require '../api/index'
iframe 	= require '../auth/iframe'
steps   = api.queue.steps

aye 	= require 'aye'

Root = ->
	body = document.getElementsByTagName('body')[0]

	body.appendChild @el = document.createElement 'div'
	@el.id = "widgetic-root"
	iframe.setRoot @

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
			api.setProxy (message)->proxy.contentWindow.postMessage message, config.domain
			
			clearTimeout timeout
			steps.init()
			Root._done = steps.init = null
			
		proxy.setAttribute 'src', config.proxy

	@

Root.connect = ->
	Root._done?()

Root.style = ->
	head = document.getElementsByTagName('head')[0]
	
	head.appendChild style = document.createElement('style')
	style.textContent = css

module.exports = Root