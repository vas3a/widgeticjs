config  = require 'config'
queue   = require 'queue-async'

editors = {}

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

module.exports = Editor