config  = require 'config'
queue   = require 'queue-async'
pubsub  = require 'pubsub.js'

api = require '../../api'

# holds references to created editors
editors = {}

# Creates an iframe with an editor for the composition
Editor = (holder, @composition) ->
	# create a queue of messages
	@_queue = queue(1)
	# get the queue continuation function
	@_queue.defer (next) => @_startQueue = next

	# register @_compReady as a callback for when the composition is ready
	@composition.queue(@_compReady.bind(this))

	# save a reference for the editor
	editors[@composition.id] = @

	# create the editor iframe
	@_iframe = document.createElement 'iframe'
	@_iframe.setAttribute 'class', 'blogvio-editor'
	holder.appendChild @_iframe
	@_iframe.setAttribute 'src', config.editor + '#' + @composition.id

	pubsub.subscribe 'api/token/update', @_updateToken.bind(@)
	@_updateToken()

	@

# Close the editor
Editor.prototype.close = ->
	editors[@composition.id] = null
	@_iframe.parentNode.removeChild(@_iframe)
	@

# Go to an editor step
# Valid steps are: skin, content, details, done
Editor.prototype.goTo = (step) ->
	steps = ['skin', 'content', 'details', 'done']
	return console.warn "The editor does not have the #{ step} step." unless step in steps
	@_sendMessage {t: 'step', d: step}
	@

# Initialize a composition save
# The editor will save the composition only if 
#  - the selected skin has no pending changes
#  - the composition meets the min and max content restrictions
Editor.prototype.save = ->
	@goTo('done')
	@

# Bind an event listener
# Supported events are:
#  - composition:save
Editor.prototype.on = (ev, callback) ->
	evs   = ev.split(' ')
	calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}
	for name in evs
		calls[name] or= []
		calls[name].push(callback)
	@

# Unbind an event listener
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

# Trigger an event
# 
# @private
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
	@_queue.defer (next) =>
		@_iframe.contentWindow.postMessage JSON.stringify(message), '*'
		next()

# Called when the editor iframe is ready, starts processing the queue
# 
# @private
Editor.prototype._ready = -> @_startQueue()

# Called when the composition is ready
# Notifies the editor that the composition is ready
# 
# @private
Editor.prototype._compReady = -> @_sendMessage {t: 'ready'}

# Called when the access token is updated (channel: api/token/update)
# Updates the editor's token
# 
# @private
Editor.prototype._updateToken = -> @_sendMessage {t: 'token', d: api.accessToken()}

# Given an editor id, calls the _ready method
# Added as a postMessage receiver in blogvio/index
Editor.connect = (data) -> editors[data.id]._ready()

# Calls _trigger on an editor with the event received from the editor iframe
Editor.event = (data) -> editors[data.id]._trigger(data.e, data.d)

module.exports = Editor