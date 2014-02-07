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

# Close the editor
Editor.prototype.close = ->
	editors[@composition.id] = null
	@_iframe.parentNode.removeChild(@_iframe)
	@

Editor.prototype.goTo = (step) ->
	steps = ['skin', 'content', 'details', 'done']
	return console.warn "The editor does not have the #{ step} step." unless step in steps
	@_sendMessage {t: 'step', d: step}
	@

Editor.prototype.save = ->
	@goTo('done')
	@

Editor.prototype.on = (ev, callback) ->
	evs   = ev.split(' ')
	calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}
	for name in evs
		calls[name] or= []
		calls[name].push(callback)
	@

Editor.prototype.off = (ev, callback) ->	
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

Editor.prototype._trigger = (args...) ->
	ev = args.shift()
	list = @hasOwnProperty('_callbacks') and @_callbacks?[ev]
	return unless list
	for callback in list
		if callback.apply(@, args) is false
			break
	true

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
Editor.connect = (data) ->
	editors[data.id]._ready()

# Calls _trigger on an editor with the event received from the iframe
Editor.event = (data) ->
	editors[data.id]._trigger(data.e, data.d)

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