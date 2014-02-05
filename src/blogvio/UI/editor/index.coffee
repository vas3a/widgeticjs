config  = require 'config'
queue   = require 'queue-async'

editors = {}

relayMessage = (editor, deferredId, status) -> (response) ->
	editor._sendMessage {
		t: 'rr',
		s: status,
		did: deferredId,
		d: response
	}

Editor = (holder, @composition) ->
	@_queue = queue(1)
	@_queue.defer (next) => @_startQueue = next

	@composition.then(@_compReady.bind(this))

	editors[@composition.id] = @

	# create the editor iframe
	@_iframe = document.createElement 'iframe'
	@_iframe.setAttribute 'class', 'blogvio-editor'
	holder.appendChild @_iframe
	@_iframe.setAttribute 'src', config.editor + '#' + @composition.id

	@

Editor.prototype._sendMessage = (message) ->
	@_iframe.contentWindow.postMessage JSON.stringify(message), '*'

Editor.prototype._ready = ->
	@_startQueue()

Editor.prototype._compReady = ->
	@_queue.defer (next) =>
		@_sendMessage {t: 'ready'}
		next()

Editor.connect = (id) ->
	editors[id.d]._ready()

Editor.relay = (event) ->
	editor = editors[event.id]
	[did, args...] = event.a
	Blogvio.api.apply(Blogvio, args)
		.then relayMessage(editor, did, 's'), relayMessage(editor, did, 'f')


module.exports = Editor