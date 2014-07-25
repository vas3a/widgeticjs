aye = require 'aye'
guid = require 'utils/guid'
json = require 'json3'
event = require 'utils/event'

config = require 'config'

log = (text, other...) ->
	console.debug('%c' + window.location.host + window.location.pathname + ' ' + text, 'background: #222; color: #bada55', other...)

extend = (out = {}) ->
  for arg in arguments
    continue unless arg

    for key of arg
      out[key] = arg[key] if arg.hasOwnProperty(key)

  return out

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
	{ promise, message }

ackMessage = (message, data) ->
	defs[message.id].resolve(data)

send = (message, target = window.parent) ->
	target = window.frames[target] if typeof target is 'string'
	target.postMessage(JSON.stringify(message), '*')

replyMessage = (message, event, response) ->
	message.d.original = message.d.event
	message.d.event = 'done'
	message.d.response = response
	send(message, event.source)

ucfirst = (string) ->
    string.charAt(0).toUpperCase() + string.slice(1)

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
		return @popups[name].init()

	# The postmessage receiver for popup ('p') messages
	# Calls the event handlers
	@receiver: (message, event) =>
		method = message.d.event
		method = 'on' + ucfirst(method)
		console?.warn 'UI.Popup: There is no handler for the event: ' + method unless @[method]		
		@[method]?(message, event)

	# Message handler
	# Will run in the parent frame
	# Creates a popup iframe with the given name and register a callback
	# to notify the caller when the iframe is ready
	@onCreate: (message, event) ->
		name = message.d.name

		# create the popup frame
		iframe = document.createElement 'iframe'
		iframe.setAttribute 'class', 'wdgtc-popup'
		iframe.setAttribute 'name', name
		iframe.setAttribute 'style', 'border: 0; width: 0; height: 0; position: absolute; top: 0; left: 0; z-index: 1000000; display: none'

		document.querySelectorAll('body')[0].appendChild iframe
		iframe.setAttribute 'src', config.popup + '&name=' + encodeURIComponent(name) + '&event=ready'
		@iframes[name] = iframe

		# save a callback for the iframe load event
		# @see @ready
		@callbacks[name] = =>
			delete @callbacks[name]
			replyMessage(message, event)

	# Message handler
	# Will run in the parent frame
	# Called when the popup iframe has loaded
	# Runs the load callback for the iframe
	@onReady: (message) -> @callbacks[message.d.name]?()

	# Message handler
	# Will run in the child frame
	# Called when the parent frame replies to the message
	# Acknowledges the message with the response sent from the parent frame
	# The handling of the event replies can be customized by creating
	# a method called "on{EventName}Done"
	@onDone: (message, event) -> 
		method = message.d.original
		method = 'on' + ucfirst(method) + 'Done'
		return @[method](message, event) if @[method]

		ackMessage(message, message.d.response)

	# Message handler
	# Will run in the child frame
	# Called when the popup iframe is ready
	# Resolves the deferred with the document object of the popup frame
	# (which can be accessed because it's also on widgetic.com)
	@onCreateDone: (message, event) -> ackMessage(message, event.source.frames[message.d.name].document)

	# Message handler
	# Will run in the parent frame
	# Handles 'manage' events
	@onManage: (message, event) ->
		name = message.d.name
		iframe = @iframes[name]
		
		method = 'do' + ucfirst(message.d.do)
		response = @[method]?(iframe, message.d)

		replyMessage(message, event, response)

	# Resizes an iframe to the given dimensions
	@doResize: (iframe, options) ->
		iframe.style.width = options.dimensions.width + 'px'
		iframe.style.height = options.dimensions.height + 'px'
		return options.dimensions

	# Hides an iframe
	@doHide: (iframe, options) -> 
		iframe.style.display = 'none'
		return

	# Shows an iframe
	@doShow: (iframe, options) ->
		iframe.style.display = 'block'
		return

	constructor: (options) ->
		# parse the options
		@options = options

		for key, value of @options
			@[key] = value

		@dimensions = { width: 0, height: 0 }

	# Sends a message to the parent frame to create an iframe
	# Used in child frame
	# Returns a promise that will be resolved
	# when the iframe has loaded (@see @created)
	init: ->
		promise = @_sendEvent('create')
		return promise.then(@_prepare)

	# Appends an DOMElement to the popup iframe body and requests a resize
	append: (el) ->
		el = el[0] if el.jquery
		log('append', el)
		@body.appendChild(el)
		return @resize()

	# Requests a resize
	resize: =>
		@dimensions = {
			width:  @body.offsetWidth
			height: @body.offsetHeight
		}
		@_sendEvent('manage', { do: 'resize', @dimensions })

	# Requests for the popup to be hid
	hide: -> @_sendEvent('manage', { do: 'hide' })

	# Requests for the popup to be shown
	show: -> @_sendEvent('manage', { do: 'show' })

	# Sends an event to the parent frame with the popup name info
	_sendEvent: (event, extra) ->
		data = { @name, event }
		data = extend(data, extra)
		{ promise, message } = newMessage(data)
		send(message)
		return promise

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

module.exports = Popup