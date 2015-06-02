config 	    = require './config'
Root 		= require './dom/root'

api 		= require './api'
auth 		= require './auth'
detect 		= require './detect'

JSON 		= require 'json3'
event 		= require './utils/event'
whenReady   = require './utils/ready'

Composition = require './UI/composition'
Editor      = require './UI/editor'
UI          = require './UI'

win 		= window

hasProxy    = false

receivers = {
	'a'	: api.request  # api
	'e'	: api.response # event
	'i'	: Root.connect # init
	'o'	: auth.connect # oauth
	'u' : Composition.connect # composition ready
	'ce': Composition.event # composition event
	'w' : Editor.connect # editor ready
	'ee': Editor.event # editor event
	'p' : UI.popup.receiver
	'r' : auth.retry
}

# remove the protocol
originRegex = "#{config.lo.replace /(http|https)\:/, ''}|#{config.domain.replace /(http|https)\:/, ''}"
# escape the dots
originRegex = originRegex.replace(/\./g, '\\.')
originRegex = new RegExp(originRegex)

receiver = (e) ->
	return unless originRegex.test e.origin
	d = e.data
	try
		return unless typeof d is "string"
		d = JSON.parse(d)
	catch error
		console.warn 'Blogvio SDK: error parsing JSON:', d
		return

	try 
		receivers[d.t]?(d, e)
	catch error
		console.error 'Blogvio SDK: ', error.stack

Blogvio = ->
	win['BlogvioAsyncInit']?()
	event.on win,'message',receiver
	detect win.location.href
	Root.style()
	UI.parse()

# TODO: move this inside Root
initProxy = ->
	return if hasProxy
	create = => 
		(@root = new Root()).createProxy()
		hasProxy = true
	if document.getElementsByTagName('body')[0]
		create()
	else
		whenReady create


Blogvio.prototype.init = (client_id, redirect_uri) ->
	initProxy()
	return @ unless (client_id and redirect_uri)
	auth.setAuthOptions client_id,redirect_uri
	@

Blogvio.prototype.api 		  = -> initProxy(); return api.apply @, arguments
Blogvio.prototype.auth  	  = -> auth.apply @, arguments
Blogvio.prototype.auth.status = -> api.getStatus.apply @, arguments
Blogvio.prototype.auth.token  = -> api.accessToken.apply @, arguments
Blogvio.prototype.auth.disconnect  = -> api.disconnect.apply @, arguments

#accessible from outside
Blogvio.prototype.JSON  	= JSON
Blogvio.prototype.Queue 	= api.queue
Blogvio.prototype.Aye		= require 'aye'
Blogvio.prototype.Event 	= event
Blogvio.prototype.GUID 		= require './utils/guid'
Blogvio.prototype.pubsub    = require 'pubsub.js'
Blogvio.prototype.require 	= require
Blogvio.prototype.EVENTS    = require './constants/events'
Blogvio.prototype.UI        = UI
Blogvio.prototype.VERSION   = '@VERSION'
Blogvio.prototype.debug     = {
	timestamp: require './utils/timestamp'
}

module.exports = Blogvio