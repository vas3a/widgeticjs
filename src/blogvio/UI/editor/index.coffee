config  = require 'config'
queue   = require 'queue-async'

# holds references to created editors
editors = {}

# Given an editor, an id and status, generates a function that
# sends a `relay response` message back to the editor.
relayMessage = (editor, deferredId, status) -> (response) ->
	editor._sendMessage {
		t: 'rr',
		s: status,
		did: deferredId,
		d: response
	}

# Creates an iframe with an editor for the composition
Editor = (holder, @composition) ->
	# create a queue of messages
	@_queue = queue(1)
	# get the queue continuation function
	@_queue.defer (next) => @_startQueue = next

	# register @_compReady as a callback for when the composition is ready
	@composition.then(@_compReady.bind(this))

	# save a reference for the editor
	editors[@composition.id] = @

	# create the editor iframe
	@_iframe = document.createElement 'iframe'
	@_iframe.setAttribute 'class', 'blogvio-editor'
	holder.appendChild @_iframe
	@_iframe.setAttribute 'src', config.editor + '#' + @composition.id

	@

# Send a message to the editor iframe
# 
# @private
Editor.prototype._sendMessage = (message) ->
	@_iframe.contentWindow.postMessage JSON.stringify(message), '*'

# Called when the editor iframe is ready, starts processing the queue
# 
# @private
Editor.prototype._ready = ->
	@_startQueue()

# Called when the composition is ready
# Notifies the editor that the composition is ready
# 
# @private
Editor.prototype._compReady = ->
	@_queue.defer (next) =>
		@_sendMessage {t: 'ready'}
		next()

# Given an editor id, calls the _ready method
# Added as a postMessage receiver in blogvio/index
Editor.connect = (id) ->
	editors[id.d]._ready()

# Receives messages from the editor iframe and relays them through
# Blogvio.api, then passes the response back to the iframe.
# 
# @example `event`
# 	{
# 		t: 'r',
# 		id: 1234 # the id of the editor
# 		a: [
# 			did, # the id of the deferred request created in the editor
# 			arguments... # the arguments to be passed to Blogvio.api
# 		] 
# 	}
Editor.relay = (event) ->
	editor = editors[event.id]
	[did, args...] = event.a
	Blogvio.api.apply(Blogvio, args)
		.then relayMessage(editor, did, 's'), relayMessage(editor, did, 'f')


module.exports = Editor