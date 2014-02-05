Root 		= require './dom/root'

api 		= require './api'
auth 		= require './auth'
detect 		= require './detect'

JSON 		= require 'json3'
event 		= require './utils/event'

Composition = require './UI/composition'
Editor      = require './UI/editor'

win 		= window

receivers = {
	'a'	: api.request  # api
	'e'	: api.response # event
	'i'	: Root.connect # init
	'o'	: auth.connect # oauth
	'u' : Composition.connect # composition ready
	'w' : Editor.connect # editor ready
}

receiver = (e) ->
	d = e.data
	try 
		receivers[(d = JSON.parse(d)).t]?(d)

Blogvio = ->
	win['BlogvioAsyncInit']?()
	event.on win,'message',receiver
	detect win.location.href
	Root.style()

Blogvio.prototype.init = (client_id,redirect_uri)->
	return @ unless (client_id and redirect_uri)
	(@root = new Root()).createProxy()
	auth.setAuthOptions client_id,redirect_uri, @root
	@

Blogvio.prototype.api 		= ->api.apply @, arguments
Blogvio.prototype.auth  	= ->auth.apply @, arguments

#accessible from outside
Blogvio.prototype.JSON  	= JSON
Blogvio.prototype.Queue 	= api.queue
Blogvio.prototype.Aye		= require 'aye'
Blogvio.prototype.Event 	= event
Blogvio.prototype.GUID 		= require './utils/guid'
Blogvio.prototype.require 	= require
Blogvio.prototype.UI        = require './UI'
module.exports = Blogvio