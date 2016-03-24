aye         = require 'aye'

config      = require './config'
Root        = require './dom/root'

api         = require './api'
auth        = require './auth'
detect      = require './detect'

JSON        = require 'json3'
event       = require './utils/event'
whenReady   = require './utils/ready'

Composition = require './UI/composition'
Editor      = require './UI/editor'
UI          = require './UI'

win         = window
winP        = win.parent

hasProxy    = false

resizeFrame = (data) ->
	ifr = document.querySelector "[name=\"#{data.d.source}\"]"
	ifr or= document.querySelector "[name=\"#{data.id}\"]"
	ifr.parentElement.style.height = data.d.height+'px'

receivers = {
	'a' : api.request  # api
	'e' : api.response # event
	'i' : Root.connect # init
	'o' : auth.connect # oauth
	'u' : Composition.connect # composition ready
	'ce': Composition.event # composition event
	'w' : Editor.connect # editor ready
	'ee': Editor.event # editor event
	'p' : UI.popup.receiver
	'r' : auth.retry
	'v' : UI.plugin.connect # plugin ready
	've': UI.plugin.event # plugin event
	'su': resizeFrame
}

# remove the protocol
originRegex = "#{config.lo.replace /(http|https)\:/, ''}|#{config.domain.replace /(http|https)\:/, ''}"
# escape the dots
originRegex = originRegex.replace(/\./g, '\\.')
originRegex = new RegExp(originRegex)

parseData = (data) ->
	def = aye.defer()

	unless typeof data is 'string'
		# "Couldn't parse event data! data should be a json!"
		def.reject()
	else
		try def.resolve JSON.parse data
		catch then def.reject new Error "error parsing JSON: #{data}"

	def.promise

# detect where the event should be passed to
# either parent frame or composition frame
proxyReceiver = (e, data) ->
	if e.source is winP
		if comp = Composition.getComp(data.d.origSource)
			# restore the original source frame
			data.d.source = data.d.origSource
			comp._iframe.contentWindow.postMessage(JSON.stringify(data), '*');
		return

	try sourceName = e.source.name
	data.d.origSource = data.d.source or sourceName
	data.d.source = win.name
	data.d.anchor?.parent = win.name
	winP.postMessage(JSON.stringify(data), '*')

# detect the right receiver and call it
callReceiver = (e, data) ->
	try sourceName = e.source.name
	# should pass the event forward (proxy message)
	# if the event type is popup and either source is window.parent 
	# or the event comes from the composition and it's target is a popup
	if isProxy = data.t in ['p', 'su'] and (e.source is winP or Composition.getComp(data.d.source or sourceName))
		return proxyReceiver(e, data)

	unless (receiver = receivers[data.t])?
		throw new Error "No receiver for #{data.t}!"
	receiver data, e

msgReceiver = (e) ->
	# do not use event if origin isn't our frame
	unless originRegex.test(e.origin) or e.source is winP
		return

	# try parsing event data, then call corresponding receiver
	parseData(e.data).then(callReceiver.bind(null, e))
		# log errors, if there are any
		.fail (error) ->
			return unless error

			if error instanceof Error
				return console.error "Widgetic SDK: ", error.stack
			console.warn "Widgetic SDK: ", error

Widgetic = ->
	win['WidgeticAsyncInit']?()
	event.on win, 'message', msgReceiver
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

Widgetic.prototype.api        = -> initProxy(); return api.apply @, arguments
Widgetic.prototype.auth       = -> auth.apply @, arguments
Widgetic.prototype.auth.register = -> auth.register.apply @, arguments
Widgetic.prototype.auth.status = -> api.getStatus.apply @, arguments
Widgetic.prototype.auth.token  = -> api.accessToken.apply @, arguments
Widgetic.prototype.auth.disconnect  = -> api.disconnect.apply @, arguments

#accessible from outside
Widgetic.prototype.JSON     = JSON
Widgetic.prototype.Queue    = api.queue
Widgetic.prototype.Aye      = aye
Widgetic.prototype.Event    = event
Widgetic.prototype.GUID         = require './utils/guid'
Widgetic.prototype.pubsub    = require 'pubsub.js'
Widgetic.prototype.require  = require
Widgetic.prototype.UI        = UI
Widgetic.prototype.EVENTS    = require './constants/events'
Widgetic.prototype.VERSION   = '@VERSION'
Widgetic.prototype.parse     = detect.parse
Widgetic.prototype.debug     = {
	timestamp: require './utils/timestamp'
}

module.exports = Widgetic
