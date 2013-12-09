aye 	= require 'aye'
rwin 	= window

link 	= {}

iframe  = (url,deffered)->
	promise = deffered.promise
	iframe 	= document.createElement 'iframe'
	
	parent 	= link.root.el
	parent.appendChild iframe
	
	fail = ->deffered.reject('Timeout error')
	
	clear = ->
		parent.removeChild iframe
		clearTimout timeout

	timeout = setTimeout  fail, 10000
	promise.then clear,clear
	iframe.setAttribute 'src', url

	promise
	
iframe.setRoot = (root)->link.root = root	
module.exports = iframe