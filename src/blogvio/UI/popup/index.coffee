aye = require 'aye'
guid = require 'utils/guid'
json = require 'json3'
event = require 'utils/event'

config = require 'config'

extend = (out = {}) ->
	for arg in arguments
		continue unless arg

		for key of arg
			out[key] = arg[key] if arg.hasOwnProperty(key)

	return out

debounce = (fn, t = 10) -> 
	_delay = null
	-> 
		clearTimeout _delay
		_delay = setTimeout fn, t

getOffset = (el) ->
	rect = el.getBoundingClientRect()
	{
		top: rect.top + document.body.scrollTop
		left: rect.left + document.body.scrollLeft
	}

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

getCssValue = (el, property) ->
	return undefined unless el
	value = window
		.getComputedStyle(el)
		.getPropertyCSSValue(property)
	
	return undefined unless value
	
	value = value.cssText 
	return undefined if value is 'none'
	return value

# Handles popup management and cross-frame popup creation
class Popup
	# Static

	# Popups created using @new (used in child frame)
	@popups: {}

	# Iframe load callbacks (used in parent frame)
	@callbacks: {}
	# Iframes created in @create (used in parent frame)
	@iframes: {}

	# Requests the creation of a new popup frame in the parent frame
	# Used in child frame
	# @return Promise
	@new: (options = {}) ->
		# create a new Popup and give it a name
		name = options.name || guid()
		options.name = name
		@popups[name] = new Popup options

		# initialize the popup iframe and return the promise
		return @popups[name].init()

	# The postmessage receiver for popup ('p') messages
	# Calls the event handlers
	@receiver: (message, event) =>
		method = message.d.event
		method = 'on' + ucfirst(method)
		@[method]?(message, event)

	# Message handler
	# Will run in the parent frame
	# Creates a popup iframe with the given name and register a callback
	# to notify the caller when the iframe is ready
	@onCreate: (message, ev) ->
		name = message.d.name

		# create the popup frame
		iframe = document.createElement 'iframe'
		iframe.setAttribute 'class', 'wdgtc-popup'
		iframe.setAttribute 'name', name
		iframe.setAttribute 'style', 'border: 0; width: 0; height: 0; position: absolute; top: 0; left: -10000px; z-index: 2147483647;'
		iframe.isVisible = false

		document.querySelectorAll('body')[0].appendChild iframe
		iframe.setAttribute 'src', config.popup + '&name=' + encodeURIComponent(name) + '&event=ready'
		@iframes[name] = iframe

		# bind on the scroll and resize events, save the handler
		iframe.doPosition = debounce @doPosition.bind(@, iframe, null), 0
		event.on window, 'resize', iframe.doPosition
		event.on window, 'scroll', iframe.doPosition

		# save a callback for the iframe load event
		# @see @ready
		@callbacks[name] = =>
			delete @callbacks[name]
			replyMessage(message, ev)

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
	# Resolves the deferred with the window object of the popup frame
	# (which can be accessed because it's also on widgetic.com)
	@onCreateDone: (message, event) -> ackMessage(message, event.source.frames[message.d.name])

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

		iframe.style.boxShadow = options.dimensions.shadow if options.dimensions.shadow
		iframe.style.borderRadius = options.dimensions.borderRadius if options.dimensions.borderRadius

		return options.dimensions

	# Hides an iframe
	@doHide: (iframe, options) -> 
		iframe.isVisible = false
		iframe.style.display = 'none'
		return

	# Shows an iframe
	@doShow: (iframe, options) ->
		iframe.isVisible = true
		iframe.style.display = 'block'
		return

	# Positions an iframe according to the anchor, anchor parent and popup options
	@doPosition: (iframe, options) ->
		if options
			iframe.positionOptions = options
		else
			return unless iframe.positionOptions
			return unless iframe.isVisible
			options = iframe.positionOptions

		offset = options.offset
		popup = options.dimensions
		anchor = extend({}, options.anchor)
		frame = document.querySelector("iframe[name=\"#{ anchor.parent }\"]")

		if frame
			{ top, left } = getOffset(frame)
			anchor.top  += top
			anchor.left += left

		# calculate the anchor position
		left = window.innerWidth + document.body.scrollLeft - (anchor.left + popup.width + offset.rightMargin + offset.leftOffset)
		left = anchor.left + offset.leftOffset + Math.min 0, left
		left = Math.max left, anchor.left + anchor.width - popup.width

		top = window.innerHeight + document.body.scrollTop - (anchor.top + anchor.height + popup.height + offset.bottomMargin)
		top = if top >= 0 then (anchor.top + anchor.height + offset.topOffset) else (anchor.top - popup.height - offset.bottomMargin)
		if top < 0 then top = anchor.top + anchor.height + offset.topOffset
		
		iframe.style.top = top + 'px'
		iframe.style.left = left + 'px'
		return

	# Removes an iframe and cleans up the memory
	@doRelease: (iframe, options) ->
		# remove the iframe from the DOM
		iframe.parentNode.removeChild iframe
		
		# unbind the events
		event.off window, 'resize', iframe.doPosition
		event.off window, 'scroll', iframe.doPosition

		# delete the reference
		name = options.name
		delete @iframes[name]

		return

	# Instance

	topOffset: 0
	leftOffset: 0
	rightMargin: 15
	bottomMargin: 15

	constructor: (options) ->
		# parse the options
		@options = options

		for key, value of @options
			@[key] = value

		@dimensions = { width: 0, height: 0 }
		@visible = false
		@styles = {}

	# Sends a message to the parent frame to create an iframe
	# Used in child frame
	# Returns a promise that will be resolved
	# when the iframe has loaded (@see @created)
	init: ->
		promise = @_sendEvent('create')
		return promise.then(@_prepare)

	# Appends an DOMElement to the popup iframe body and requests a resize
	# Replaces the iframe content
	append: (el) ->
		el = el[0] if el.jquery

		@body.innerHTML = '';
		@body.appendChild(el)

		@styles = {}
		@_updateCachedStyles(el)

		return @resize()

	# Requests a resize
	resize: =>
		@dimensions = {
			width:  @body.offsetWidth
			height: @body.offsetHeight
			shadow: @styles['box-shadow']
			borderRadius: @styles['border-radius']
		}
		@_sendEvent('manage', { do: 'resize', @dimensions })

	# Requests for the popup to be hid
	hide: -> @_sendEvent('manage', { do: 'hide' }).then => @visible = false

	# Requests for the popup to be shown
	show: -> @position().then => @_sendEvent('manage', { do: 'show' }).then => @visible = true

	# Requests for the popup to be positioned
	position: => 
		offset = { @topOffset, @leftOffset, @bottomMargin, @rightMargin }
		anchor = { top: 0, left: 0, width: 0, height: 0 }

		if @anchor.jquery
			anchor = @anchor.offset()
			anchor.width  = parseInt @anchor.outerWidth(), 10
			anchor.height = parseInt @anchor.outerHeight(), 10
			anchor.parent = window.name

		@_sendEvent('manage', { do: 'position', anchor, @dimensions, offset })

	# Requests for the popup to be released
	release: ->
		deferred = aye.defer()
		promise = deferred.promise

		# reload the iframe
		@document.location.reload()

		# send the release event after the reload finishes
		setTimeout deferred.resolve, 1000
		promise.then => @_sendEvent('manage', { do: 'release' })

	# Sends an event to the parent frame with the popup name info
	_sendEvent: (event, extra) ->
		data = { @name, event }
		data = extend(data, extra)
		{ promise, message } = newMessage(data)
		send(message)
		return promise

	# Caches relevant nodes from the iframe and styles the contents
	_prepare: (@window) =>
		# save the document and important nodes
		@document = @window.document
		@body = @document.getElementsByTagName('body')[0]
		@head = @document.getElementsByTagName('head')[0]

		# load the styles
		styles = '<style type="text/css">body{display:inline-block;margin:0;width:auto !important;height:auto !important;overflow:hidden;background:transparent !important}</style>'
		@head.insertAdjacentHTML 'beforeend', styles

		onLoad = =>			
			@_updateCachedStyles(@body.children[0]) if @body.children[0]
			@resize()
		loadSheet sheet, @head, onLoad for sheet in @css if @css

		return @

	_updateCachedStyles: (el) ->		
		@_cacheStyle(el, 'box-shadow')
		# TODO: check what's happening to border-radius on firefox (missing)
		@_cacheStyle(el, 'border-radius')

	_cacheStyle: (el, value) -> 
		@styles[value] = getCssValue(el, value)

module.exports = Popup