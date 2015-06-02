config = require 'config'
guid   = require 'utils/guid'
queue  = require 'queue-async'
api    = require '../../api'
auth   = require '../../auth'

# Holds references to created compositions
comps  = {}

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
Composition = (holder, data, brand_pos) ->
	Blogvio.debug.timestamp 'Blogvio.UI.Composition:constructor'
	# create the queue of messages
	@_queue = queue(1)
	# get the queue continuation function,
	# so we can start the queue when the iframe is ready
	@_queue.defer (next) => @_startQueue = next

	# get the url
	if typeof data is 'string'
		url = config.composition.replace('{id}', data)
	else if typeof data is 'object'
		url = config.widget.replace('{id}', data.widget_id)
		# load local/temp composition
		url+= "#comp=#{data.id}" if data.id?
		@setSkin data.skin if data.skin
		@setContent data.content if data.content

	query = []

	brand_pos or= data.brand_pos
	query.push 'bp='+brand_pos if brand_pos

	client_id = auth.getClientId()
	if data.widget_id? and not client_id
		throw new Error 'Blogvio should be initialized before using the UI.Composition!'

	query.push 'access_token='+token if token = data.token or api.accessToken()
	query.push 'client_id='+client_id if client_id
	query.push 'wait' if data.wait_editor_init

	url = url.replace /(\?)|((.)(\#)|($))/, "?#{query.join '&' if query.length}&$2" if query.length

	# generate a unique id and save a reference to this composition
	@id = guid()
	comps[@id] = @

	# create the iframe
	@_iframe = document.createElement 'iframe'
	@_iframe.setAttribute 'class', 'blogvio-composition'
	@_iframe.setAttribute 'name', @id
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
	Blogvio.debug.timestamp 'Blogvio.UI.Composition:_ready'
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
Composition.prototype.on = (ev, callback) ->
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
# This method is defined in blogvio\index as a receiver for the 'u' event
# type, which is sent by the Composition's iframe when finished loading.
Composition.connect = (id) ->
	comps[id.d]._ready()

# Calls _trigger on an editor with the event received from the editor iframe
Composition.event = (data) -> 
	comps[data.id]._trigger(data.e, data.d)

module.exports = Composition