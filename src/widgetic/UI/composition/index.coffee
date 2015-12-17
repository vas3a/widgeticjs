config = require 'config'
guid   = require 'utils/guid'
queue  = require 'queue-async'
api    = require '../../api'
auth   = require '../../auth'

# Holds references to created compositions
comps  = {}

relayedEvents = [
	'click'
	'dblclick'
	'mousedown'
	'mousemove'
	'mouseup'
	'mouseenter'
	'mouseleave'
	'mouseover'
	'mouseout'
	'wheel'
	'keydown'
	'keyup'
	'keypress'
]

# Creates an iframe for the composition in the `holder`
# 
# @param [Node] holder the DOM Node where we should insert the iframe
# @param [String, Object] data a composition ID or a new composition
# @example `data` as a new composition
# 	{
# 		widget_id: "5108dcefe599d12e6f000000",
# 		skin_id: "5108dcefe599d12e6f000000-p1",
# 		content: [
# 			{
# 				'id': '1',
# 				'order': '1',
# 				"image": "http://farm3.staticflickr.com/2537/4149237871_d2fa01210d.jpg"
# 			},
# 			{
# 				'id': '2',
# 				'order': '2',
# 				"image": "http://placehold.it/500x375"
# 			}
# 		]
# 	}
Composition = (holder, opt1, opt2 = {}) ->
	composition = opt1 if typeof opt1 is 'string'
	options = if composition then opt2 else opt1
	composition ?= options.composition

	Widgetic.debug.timestamp 'Widgetic.UI.Composition:constructor'
	# create the queue of messages
	@_queue = queue(1)
	# get the queue continuation function,
	# so we can start the queue when the iframe is ready
	@_queue.defer (next) => @_startQueue = next

	# get the url
	if composition
		url = config.composition.replace '{id}', composition
	else
		url = config.widget.replace('{id}', options.widget_id)
		# load local/temp composition
		url+= "#comp=#{options.id}" if options.id?
		@setSkin options.skin if options.skin
		@setContent options.content if options.content

	query = []

	client_id = auth.getClientId()
	has_token = api.getStatus().status is 'connected'
	if options.widget_id? and not (client_id or has_token)
		throw new Error 'Widgetic should be initialized before using the UI.Composition!'

	query.push 'access_token='+token if token = options.token or api.accessToken()
	query.push 'client_id='+client_id if client_id
	query.push 'wait' if options.wait_editor_init
	query.push 'branding' if options.branding
	query.push 'bp='+options.brand_pos if options.brand_pos
	query.push 'edit_mode' if options.edit_mode

	url = url.replace /(\?)|((.)(\#)|($))/, "?#{query.join '&' if query.length}&$2" if query.length

	# generate a unique id and save a reference to this composition
	@id = guid()
	comps[@id] = @

	# create the iframe
	@_iframe = document.createElement 'iframe'
	@_iframe.setAttribute 'class', 'widgetic-composition'
	@_iframe.setAttribute 'name', @id
	@_iframe.setAttribute 'allowfullscreen', true
	holder.appendChild @_iframe
	@_iframe.setAttribute 'src', url

	@

Composition.prototype.close = ->
	comps[@id] = null
	@_iframe.parentNode.removeChild @_iframe
	@off()
	@

Composition.prototype.queue = (callback) ->
	@_queue.defer (next) =>
		callback()
		next()

# Starts the message queue. Called when the iframe is loaded.
# 
# @private
Composition.prototype._ready = ->
	Widgetic.debug.timestamp 'Widgetic.UI.Composition:_ready'
	@_startQueue()

# Adds a postMessage to the queue
# 
# @param [Object] message an object with a message type and data
# @example A message
# 	{
# 		t: 'sc',
# 		d: [
# 			{
#				'id': '1',
#				'order': '1',
#				"image": "http://farm3.staticflickr.com/2537/4149237871_d2fa01210d.jpg"
#			},
#			{
#				'id': '2',
#				'order': '2',
#				"image": "http://placehold.it/500x375"
#			}
#		]
# 	}
# @private
Composition.prototype._sendMessage = (message) ->
	@_queue.defer (next) => 
		@_iframe.contentWindow.postMessage JSON.stringify(message), '*'
		next()
	@

# Bind an event listener
# Supported events are:
#  - composition:save
#  - relayedEvents
Composition.prototype.on = (ev, callback) ->
	if ev in relayedEvents then @_sendMessage(t: 're', d: ev)

	evs   = ev.split(' ')
	calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}
	for name in evs
		calls[name] or= []
		calls[name].push(callback)
	@

# Unbind an event listener
Composition.prototype.off = (ev, callback) ->	
	if arguments.length is 0
		@_callbacks = {}
		return @
	return @ unless ev
	evs = ev.split(' ')
	for name in evs
		list = @_callbacks?[name]
		continue unless list
		unless callback
			delete @_callbacks[name]
			continue
		for cb, i in list when (cb is callback)
			list = list.slice()
			list.splice(i, 1)
			@_callbacks[name] = list
			break
	@

# Trigger an event
# 
# @private
Composition.prototype._trigger = (args...) ->
	ev = args.shift()
	ev = args[0].type if ev is Composition.RELAY

	list = @hasOwnProperty('_callbacks') and @_callbacks?[ev]
	return unless list
	for callback in list
		if callback.apply(@, args) is false
			break
	true

# Add these methods to the Composition prototype to define the public API.
# Each method is a call to _sendMessage with the respective messageType.
# The iframe should listen to these messages and modify the widget.
methods = {
	'clearContent':  'cx'
	'setContent':    'sc'
	'addContent':    'ac'
	'changeContent': 'cc'
	'removeContent': 'rc'
	'setSkin':       'ss'
	'changeSkin':    'cs'
	'removeSkin':    'rs'
	'saveSkin':      'sS'
	'save':          's'
	'saveDraft':     'sd'
	'setName':       'sn'
}

for method, messageType of methods
	do (method, messageType) ->
		Composition.prototype[method] = (data) -> @_sendMessage(t: messageType, d: data)

# Given an id, calls the _ready method on a composition.
# This method is defined in widgetic\index as a receiver for the 'u' event
# type, which is sent by the Composition's iframe when finished loading.
Composition.connect = (id) ->
	comps[id.d]._ready()

# Calls _trigger on an editor with the event received from the editor iframe
Composition.event = (data) -> 
	comps[data.id]._trigger(data.e, data.d)

Composition.RELAY = 'r'
Composition.EMBED_MODE = 1
Composition.EDIT_MODE  = 2

module.exports = Composition