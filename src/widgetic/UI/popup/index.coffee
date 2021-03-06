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

	if callback
		event.on link, 'load', callback
		event.on link, 'error', callback

	el.appendChild link

loadSheets = (el, sheets = [], optional = [], callback) ->
	allSheets = [].concat sheets, optional
	total = allSheets.length

	loadedSheets = 0
	waiting = true
	onLoad = (ev) =>
		# if ev.type is loaded or the stylesheet is an optional one,
		# increment the loadedSheets counter
		if ev.type is 'load' or optional.indexOf(ev.target.href) > -1
			++loadedSheets
		else
			# a required stylesheet has failed to load
			# reject the promise
			console.log new Error "Popup stylesheet \"#{ev.target.href}\" did not load!"

		# resolve the deferred if all sheets have been loaded or no longer waiting
		callback() if loadedSheets is total or !waiting

	# load all stylesheets
	loadSheet sheet, el, onLoad for sheet in allSheets

	# assume the css won't load if more than 5 seconds pass, stop waiting for the rest of the css
	setTimeout callback, 5000
	setTimeout (-> waiting = false), 5000

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
		.getPropertyValue(property)

	return undefined unless value
	return value

getTextFromStyleElement = (el) ->
	try
		el.innerHTML
	catch
		el.styleSheet.cssText

clientRectToObject = (clientRect) ->
	res = {}
	return res unless clientRect
	res[key] = value for key, value of clientRect
	return res


_getInfo = (popupIframe) ->
	return {
		popup: clientRectToObject(popupIframe.getBoundingClientRect())
		widget: clientRectToObject(popupIframe._parentFrame?.getBoundingClientRect())
	}

# Handles popup management and cross-frame popup creation
class Popup
	# Static
	@styles: {
		popup: '
			body {
				display:inline-block;
				margin:0;
				width:auto !important;
				height:auto !important;
				overflow:hidden;
				background:transparent !important
			}

			#loader {
				width: 250px;
				height: 250px;
				border: 1px solid #d5d5d5;
				background: white;
			}

			.sk-three-bounce {
				margin: 115px auto;
				width: 40px;
				text-align: center; }
				.sk-three-bounce .sk-child {
					width: 10px;
					height: 10px;
					background-color: #262424;
					border-radius: 100%;
					display: inline-block;
					-webkit-animation: sk-three-bounce 1.4s ease-in-out 0s infinite both;
									animation: sk-three-bounce 1.4s ease-in-out 0s infinite both; }
				.sk-three-bounce .sk-bounce1 {
					-webkit-animation-delay: -0.32s;
									animation-delay: -0.32s; }
				.sk-three-bounce .sk-bounce2 {
					-webkit-animation-delay: -0.16s;
									animation-delay: -0.16s; }

			@-webkit-keyframes sk-three-bounce {
				0%, 80%, 100% {
					-webkit-transform: scale(0);
									transform: scale(0); }
				40% {
					-webkit-transform: scale(1);
									transform: scale(1); } }

			@keyframes sk-three-bounce {
				0%, 80%, 100% {
					-webkit-transform: scale(0);
									transform: scale(0); }
				40% {
					-webkit-transform: scale(1);
									transform: scale(1); } }
		'
		overlay: '
			html, body {
				width:100%;
				height:100%;
			}
			body {
				display:block;
				margin:0;
				overflow:hidden;
			}
		'
	}

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
		iframe.isOverlay = message.d.type is 'overlay'
		iframe.setAttribute 'style', 'border: 0; width: 0; height: 0; position: absolute; top: 0; left: -10000px; z-index: 2147483646;'
		iframe.style.zIndex = 2147483647 if iframe.isOverlay # keep overlays over popups
		iframe.isVisible = false
		# save requesting iframe as parent
		iframe._parent = ev.source
		iframe._parentFrame = document.getElementsByName(message.d.source)[0]

		document.querySelectorAll('body')[0].appendChild iframe
		iframe.setAttribute 'src', config.popup + '&name=' + encodeURIComponent(name) + '&event=ready'
		@iframes[name] = iframe

		# bind on the scroll and resize events, save the handler
		iframe.doPosition = =>
			@doPosition(iframe, null)
			msg = {t: 'p', d: {event: 'reposition', name, response: {info: _getInfo(iframe)}}}
			send(msg, iframe._parent)
		iframe.doPosition = debounce iframe.doPosition
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
	@onCreateDone: (message, event) ->
		{source} = event
		# if frame wasn't found in event's source frames
		# try looking for it in parents frames
		unless popupFrame = source.frames[message.d.name]
			# iterate 'till top frame
			while source isnt event.source.top
				source = source.parent
				try break if popupFrame = source.frames[message.d.name]

		ackMessage(message, popupFrame)

	@onReposition: (message, event) ->
		@popups[message.d.name].info = message.d.response.info
		@popups[message.d.name].trigger('reposition')

	# Message handler
	# Will run in the parent frame
	# Handles 'manage' events
	@onManage: (message, event) ->
		name = message.d.name
		iframe = @iframes[name]

		method = 'do' + ucfirst(message.d.do)
		response = @[method]?(iframe, message.d) || {}
		response.info = _getInfo(iframe)

		replyMessage(message, event, response)

	# Resizes an iframe to the given dimensions
	@doResize: (iframe, options) ->
		return options.dimensions if iframe.isOverlay

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
		iframe.style.display  = 'block'
		iframe.style.position = if iframe.isOverlay then 'fixed' else 'absolute'
		return

	# Positions an iframe according to the anchor, anchor parent and popup options
	@doPosition: (iframe, options) ->
		iframe.style.display = "none" unless iframe.isVisible

		if iframe.isOverlay
			iframe.style.position = 'fixed'
			iframe.style.width   = '100%'
			iframe.style.height  = '100%'
			iframe.style.top     = 0
			iframe.style.left    = 0
			iframe.style.bottom  = 0
			iframe.style.right   = 0
			return

		if options
			iframe.positionOptions = options
		else
			return unless iframe.positionOptions
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
		left = Math.max(0, anchor.left + offset.leftOffset + Math.min 0, left)

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

	# Hides all visible popups
	# Usable in the parent frame
	@hideAll: ->
		iframes = for id, iframe of Popup.iframes
			iframe

		# close visible iframes
		iframes.filter((iframe) -> iframe.isVisible)
			.map (iframe) ->
				Popup.doHide(iframe)
				# send event to popup's parent frame for processing
				send({t: 'p', d: {event: 'hide', name: iframe.name}}, iframe._parent)

	# Message handler
	# Will run in the child frame
	# Triggered by Popup.hideAll
	# @example message format:
	#	{
	#		t: "p", #popup channel
	#		d: {
	#			event: "hide" # event name
	#			name: "1770735e-10bf-7c8d-57e8-a6e9ab93cbd3" # the name of the popup
	#		}
	#	}
	@onHide: (message, event) ->
		popup = @popups[message.d.name]
		popup._hide()

	# Instance

	type: 'popup'
	topOffset: 0
	leftOffset: 0
	rightMargin: 15
	bottomMargin: 15
	copyStyles: true

	constructor: (options) ->
		# parse the options
		@options = options

		for key, value of @options
			@[key] = value

		@anchor ?= document.body
		@anchor = @anchor[0] if @anchor.jquery

		@dimensions = { width: 0, height: 0 }
		@info = {}
		@visible = false
		@_callbacks = {}

	on: (ev, callback) ->
		@_callbacks[ev] = @_callbacks[ev] || []
		@_callbacks[ev].push(callback)

	off: (ev) ->
		if ev then return @_callbacks[ev] = []
		@_callbacks = {}

	trigger: (ev, data) ->
		return unless @_callbacks[ev]
		for callback in @_callbacks[ev]
			callback(data)

	# Sends a message to the parent frame to create an iframe
	# Used in child frame
	# Returns a promise that will be resolved
	# when the iframe has loaded (@see @created)
	init: ->
		promise = @_sendEvent('create', { @type, source: window.name })
		return promise.then(@_prepare)

	# Appends an DOMElement to the popup iframe body and requests a resize
	# Replaces the iframe content
	append: (el) ->
		el = el[0] if el.jquery

		@content.innerHTML = '';
		@content.appendChild(el)

		return @resize()

	style: (text, preserve = false) ->
		unless @styleElement
			@styleElement = document.createElement('style')
			@head.appendChild @styleElement

		@preservedStyles ?= ''

		try
			@styleElement.innerHTML = @preservedStyles + text
		catch
			@styleElement.styleSheet.cssText = @preservedStyles + text

		@preservedStyles += text if preserve

		# send a resolved deferred to keep the API consistent
		deferred = aye.defer()
		deferred.resolve(@preservedStyles + text)
		return deferred.promise


	# Requests a resize
	resize: =>
		@dimensions = {
			width:  @document.body.offsetWidth
			height: @document.body.offsetHeight
		}
		@_sendEvent('manage', { do: 'resize', @dimensions })
			.then @_saveInfo

	# Requests for the popup to be hid
	hide: -> @_sendEvent('manage', { do: 'hide' }).then(@_saveInfo).then @_hide
	_hide: => @visible = false

	# Requests for the popup to be shown
	show: ->
		@position()
			.then => @_sendEvent('manage', { do: 'show' })
			.then(@_saveInfo)
			.then => @visible = true


	# Requests for the popup to be positioned
	position: =>
		offset = { @topOffset, @leftOffset, @bottomMargin, @rightMargin }

		anchor = getOffset(@anchor)
		anchor.parent = window.name
		anchor.width  = parseInt @anchor.offsetWidth, 10
		anchor.height = parseInt @anchor.offsetHeight, 10

		@_sendEvent('manage', { do: 'position', anchor, @dimensions, offset })
			.then @_saveInfo

	# Requests for the popup to be released
	release: ->
		deferred = aye.defer()
		promise = deferred.promise

		# reload the iframe
		@document.location.reload()

		# send the release event after the reload finishes
		setTimeout deferred.resolve, 1000
		promise.then => @_sendEvent('manage', { do: 'release' })

	_saveInfo: (response) =>
		@info = response.info
		return response

	# Sends an event to the parent frame with the popup name info
	_sendEvent: (event, extra) ->
		data = { @name, event }
		data = extend(data, extra)
		{ promise, message } = newMessage(data)
		send(message, @targetWindow)
		return promise

	# Caches relevant nodes from the iframe and styles the contents
	_prepare: (@window) =>
		# save the document and important nodes
		@document = @window.document
		@head = @document.head

		@loader = document.createElement('div')
		@loader.id = 'loader'
		@loader.style.display = 'none'
		@loader.innerHTML = '<div class="sk-three-bounce">
				<div class="sk-child sk-bounce1"></div>
				<div class="sk-child sk-bounce2"></div>
				<div class="sk-child sk-bounce3"></div>
			</div>'
		@document.body.appendChild(@loader)
		@content = document.createElement('div')
		@document.body.appendChild(@content)

		# load the styles
		styles = '<style type="text/css">' + Popup.styles[@type] + '</style>'
		@head.insertAdjacentHTML 'beforeend', styles

		# copy over widget-styles
		styles = document.querySelectorAll '[data-widget-style=true]'
		styles = Array::map.call styles, getTextFromStyleElement
		styles = styles.reduce ( (previous, current) -> previous += current ), ''
		@style(styles, true)

		# copy over linked stylesheets
		# TODO remove this, as it does not make sense in the general case
		sheets = document.querySelectorAll 'link[rel="stylesheet"]'
		sheets = Array::map.call sheets, (el) => el.href

		if @css or sheets.length
			@loader.style.display = 'block'
			@content.style.display = 'none'
			loadSheets @head, @css, sheets, =>
				@loader.style.display = 'none'
				@content.style.display = 'block'
				@resize()
					.then => @position()
					.then => return @

		return @

# listen for clicks to hide popups
event.on window.document, 'click', Popup.hideAll

module.exports = Popup
