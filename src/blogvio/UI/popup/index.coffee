aye = require 'aye'
guid = require 'utils/guid'
json = require 'json3'
event = require 'utils/event'

config = require 'config'

log = (text, other...) ->
	console.debug('%c' + window.location.host + window.location.pathname + ' ' + text, 'background: #222; color: #bada55', other...)
		 
loadSheet = (url, el, callback) ->
	link = @document.createElement 'link'
	link.setAttribute 'rel', 'stylesheet'
	link.setAttribute 'type', 'text/css'
	link.setAttribute 'charset', 'utf-8'
	link.setAttribute 'href', url
	event.on link, 'load', callback if callback
	el.appendChild link

defs = {}

newMessage = (data) ->
	defid   = guid()
	promise = (defs[defid] = deffered = aye.defer()).promise
	message = {id: defid, t: 'p', d: data}
	{promise, message}

ackMessage = (message, data) ->
	defs[message.id].resolve(data)

send = (message, target = window.parent) ->
	target = window.frames[target] if typeof target is 'string'
	target.postMessage(JSON.stringify(message), '*')

# Handles popup management and cross-frame popup creation
class Popup
	# Popups created using @new (used in child frame)
	@popups: {}

	# Iframe load callbacks (used in parent frame)
	@callbacks: {}
	# Iframes created in @create (used in parent frame)
	@iframes: {}

	# Requests the creation of a new popup frame in the parent frame
	# Used in child frame
	# @return Promise
	@new: (options) ->
		log('Popup.new', window.name)
		# create a new Popup and give it a name
		name = guid()
		options.name = name
		@popups[name] = new Popup options

		# initialize the popup iframe and return the promise
		return @init(@popups[name])

	# The postmessage receiver for popup ('p') messages
	# Calls the event handlers
	@receiver: (message, event) =>
		method = message.d.event
		@[method]?(message, event)

	# Sends a message to the parent frame to create an iframe
	# Used in child frame
	# Returns a promise that will be resolved
	# when the iframe has loaded (@see @created)
	@init: (popup) ->
		{promise, message} = newMessage({ name: popup.name, event: 'create' })
		send(message)
		return promise.then(popup._prepare)

	# Message handler
	# Will run in the parent frame
	# Creates a popup iframe with the given name and register a callback
	# to notify the caller when the iframe is ready
	@create: (message, event) ->
		name = message.d.name

		# create the popup frame
		iframe = document.createElement 'iframe'
		iframe.setAttribute 'class', 'wdgtc-popup'
		iframe.setAttribute 'name', name
		iframe.setAttribute 'style', 'border: 0; width: 0; height: 0; position: absolute; top: 0; left: 0; z-index: 1000000'

		document.querySelectorAll('body')[0].appendChild iframe
		iframe.setAttribute 'src', config.popup + '&name=' + encodeURIComponent(name) + '&event=ready'
		@iframes[name] = iframe

		# save a callback for the iframe load event
		# @see @ready
		@callbacks[name] = =>
			delete @callbacks[name]
			# notify load
			message.d.event = 'created'
			send(message, event.source)

	# Message handler
	# Will run in the parent frame
	# Runs the load callback for the iframe
	@ready: (message) -> @callbacks[message.d.name]?()

	# Message handler
	# Will run in the child frame
	# Called when the popup iframe is ready
	# Resolves the deferred with the document object of the popup frame
	# (which can be accessed because it's also on widgetic.com)
	@created: (message, event) -> ackMessage(message, event.source.frames[message.d.name].document)

	@resize: (message, event) ->
		name = message.d.name
		iframe = @iframes[name]

		iframe.style.width = message.d.dimensions.width + 'px'
		iframe.style.height = message.d.dimensions.height + 'px'

		message.d.event = 'resized'
		send(message, event.source)

	@resized: (message, event) -> ackMessage(message, message.d.dimensions)

	constructor: (options) ->
		# parse the options
		@options = options

		for key, value of @options
			@[key] = value

		@dimensions = { width: 0, height: 0 }

	# Caches relevant nodes from the iframe and styles the contents
	_prepare: (document) =>
		# save the document and important nodes
		@document = document
		@body = document.getElementsByTagName('body')[0]
		@head = document.getElementsByTagName('head')[0]

		# load the styles
		styles = '<style type="text/css">body{display:inline-block;margin:0;width:auto !important;height:auto !important}</style>'
		@head.insertAdjacentHTML 'beforeend', styles
		loadSheet sheet, @head, @resize for sheet in @css

		return @

	append: (el) ->
		el = el[0] if el.jquery
		log('append', el)
		@body.appendChild(el)
		return @resize()
		# @resize().then(@reposition)

	resize: =>
		@dimensions = {
			width:  @body.offsetWidth
			height: @body.offsetHeight
		}
		{promise, message} = newMessage({ @name, event: 'resize', @dimensions })
		send(message)
		return promise

	hide: -> log('hide')

	show: -> log('show')

module.exports = Popup