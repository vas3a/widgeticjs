config = require 'config'
guid   = require 'utils/guid'
queue  = require 'queue-async'

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
Composition = (holder, data) ->
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
		@setSkin data.skin if data.skin
		@setContent data.content if data.content

	# generate a unique id and save a reference to this composition
	@id = guid()
	comps[@id] = @
	url += '#' + @id

	# create the iframe
	@_iframe = document.createElement 'iframe'
	@_iframe.setAttribute 'class', 'blogvio-composition'
	@_iframe.setAttribute 'name', @id
	holder.appendChild @_iframe
	@_iframe.setAttribute 'src', url

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

# Add these methods to the Composition prototype to define the public API.
# Each method id a call to _sendMessage with the respective messageType.
# The iframe should listen to these messages and modify the widget.
methods = {
	'clearContent':  'cx'
	'setContent':    'sc'
	'addContent':    'ac'
	'changeContent': 'cc'
	'removeContent': 'rc'
	'setSkin':       'ss'
	'changeSkin':    'cs'
}

for method, messageType of methods
	do (method, messageType) ->
		Composition.prototype[method] = (data) -> @_sendMessage(t: messageType, d: data)

# Given an id, calls the _ready method on a composition.
# This method is defined in blogvio\index as a receiver for the 'u' event
# type, which is sent by the Composition's iframe when finished loading.
Composition.connect = (id) ->
	comps[id.d]._ready()

module.exports = Composition