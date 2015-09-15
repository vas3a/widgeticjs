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
	'v' : UI.plugin.connect # plugin ready
	've': UI.plugin.event # plugin event
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
		console.warn 'Widgetic SDK: error parsing JSON:', d
		return

	try 
		receivers[d.t]?(d, e)
	catch error
		console.error 'Widgetic SDK: ', error.stack

Widgetic = ->
	win['WidgeticAsyncInit']?()
	event.on win,'message',receiver
	detect win.location.href
	Root.style()
	setTimeout UI.parse

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


Widgetic.prototype.init = (client_id, redirect_uri) ->
	initProxy()
	return @ unless (client_id and redirect_uri)
	auth.setAuthOptions client_id,redirect_uri
	@

Widgetic.prototype.api 		  = -> initProxy(); return api.apply @, arguments
Widgetic.prototype.auth  	  = -> auth.apply @, arguments
Widgetic.prototype.auth.register = -> auth.register.apply @, arguments
Widgetic.prototype.auth.status = -> api.getStatus.apply @, arguments
Widgetic.prototype.auth.token  = -> api.accessToken.apply @, arguments
Widgetic.prototype.auth.disconnect  = -> api.disconnect.apply @, arguments

#accessible from outside
Widgetic.prototype.JSON  	= JSON
Widgetic.prototype.Queue 	= api.queue
Widgetic.prototype.Aye		= require 'aye'
Widgetic.prototype.Event 	= event
Widgetic.prototype.GUID 		= require './utils/guid'
Widgetic.prototype.pubsub    = require 'pubsub.js'
Widgetic.prototype.require 	= require
Widgetic.prototype.UI        = UI
Widgetic.prototype.EVENTS    = require './constants/events'
Widgetic.prototype.VERSION   = '@VERSION'
Widgetic.prototype.debug     = {
	timestamp: require './utils/timestamp'
}

module.exports = Widgetic