aye = require 'aye'
guid = require 'utils/guid'
json = require 'json3'

config = require 'config'

send = (message, target = window.parent) ->
	target = window.frames[target] if typeof target is 'string'
	target.postMessage(JSON.stringify(message), '*')

log = (text, other...) ->
	console.log('%c' + window.location.host + window.location.pathname + ' ' + text, 'background: #222; color: #bada55', other...)

# Handles popup management and cross-frame popup creation
class Popup
	@defs: {}
	@popups: {}
	@callbacks: {}

	# Creates a new popup frame in the parent frame
	# @return Promise
	@new: (options) ->
		log('Popup.new', window.name)
		# create a new Popup and give it a name
		name = guid()
		@popups[name] = new Popup { name }

		# initialize the popup iframe and return the promise
		return @popups[name].init()

	# The postmessage receiver for popup ('p') messages
	# Calls the event handlers
	@receiver: (message, event) =>
		debugger
		method = message.d.event
		@[method]?(message, event)

	# Message handler
	# Will run in the parent window
	# Creates a popup iframe with the given name and notifies the caller
	# when the iframe is ready
	@create: (message, event) ->
		debugger
		log('Popup.create', message)
		name = message.d.name

		# create the popup frame
		iframe = document.createElement 'iframe'
		iframe.setAttribute 'class', 'wdgtc-popup'
		iframe.setAttribute 'name', name

		document.querySelectorAll('body')[0].appendChild iframe
		iframe.setAttribute 'src', config.popup + '&name=' + encodeURIComponent(name) + '&event=ready'

		# save a callback for the 
		@callbacks[name] = =>
			delete @callbacks[name]
			# notify load
			message.d.event = 'created'
			send(message, event.source)

	# Message handler
	# Will run in the parent window
	@ready: (message) ->
		debugger
		log('Popup.ready', message)
		@callbacks[message.d.name]?()

	# Message handler
	# Will run in the child window
	@created: (message, event) ->
		debugger
		event.source.frames[message.d.name].document
		@defs[message.id].resolve('ceva')
		log('Popup.created', message)

	constructor: (options) ->
		# parse the options
		@options = options

		for key, value of @options
			@[key] = value

	# Sends a message to the parent sdk.js to create an iframe
	# Returns a promise that will be resolved when the iframe has loaded
	init: ->
		defid   = guid()
		promise = (Popup.defs[defid] = deffered = aye.defer()).promise

		message = {id: defid, t: 'p', d: { @name, event: 'create' }}
		send(message)

		return promise

module.exports = Popup