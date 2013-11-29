Root 		= require './dom/root'

api 		= require './api'
auth 		= require './auth'
detect 		= require './detect'

JSON 		= require 'json3'
event 		= require './utils/event'

win 		= window

receivers = {
	'a'	: api.request
	'e'	: api.response
	'i'	: Root.connect
	'o'	: auth.connect
}

receiver = (e)->
	d = e.data
	try 
		receivers[(d = JSON.parse(d)).t]?(d)

Blogvio = ->
	win['BlogvioAsyncInit']?()
	event.on win,'message',receiver
	detect win.location.href

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
module.exports = Blogvio