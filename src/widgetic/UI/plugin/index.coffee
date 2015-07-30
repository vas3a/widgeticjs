config  = require 'config'
queue   = require 'queue-async'
pubsub  = require 'pubsub.js'
guid    = require 'utils/guid'

api = require '../../api'

# Creates an iframe for plugin
class Plugin
	@instances: {}
	# Given an plugin id, calls the _ready method
	# Added as a postMessage receiver in widgetic/index
	@connect: (data) =>
		instance = @instances[data.id]
		instance._updateToken()
		instance._ready()
		instance._sendMessage t: 'ready'

	# Calls _trigger on an plugin with the event received from the plugin iframe
	@event: (data) =>
		@instances[data.id]._trigger(data.e, data.d)

	@create: (opts={}) ->
		instance = new @ opts
		@instances[instance.id] = instance

	constructor: (opts) ->
		@id = guid()
		@name = opts.name || @id
		Widgetic.debug.timestamp 'Widgetic.UI.Plugin:constructor'
		# create a queue of messages
		@_queue = queue(1)
		# get the queue continuation function
		@_queue.defer (next) => @_startQueue = next

		# send the access token to the iframe
		pubsub.subscribe 'api/token/update', @_updateToken.bind(@)
		@_updateToken()

		@setOptions opts if opts

		# create the plugin iframe
		url = config.plugin
		if @frame = opts.holder?.document or opts.holder
			@_iframe = document.createElement 'iframe'
			@_iframe.setAttribute 'class', 'wdtc-plugin'
			@_iframe.setAttribute 'name', @name
			@frame.appendChild @_iframe
			@_iframe.setAttribute 'src', url
			@frame = @_iframe.contentWindow
		else
			@frame = window.open url, @name, "height=#{opts.h or 760},width=#{opts.w or 1270}"

	# Close the plugin
	close: ->
		@constructor.instances[@id] = null
		delete @constructor.instances[@id]
		if @_iframe
			@_iframe.parentNode.removeChild @_iframe
		else
			@frame.close()
		@

	# Set custom options for plugin
	# options = {
	#   id: composition id,
	#   width: embed's width,
	#   height: embed's height,
	#   resizeMode: embed's resize mode
	# }
	setOptions: (@options = @options) ->
		@_sendMessage {t: 'opts', d: @options}
		@

	# Bind an event listener
	# Supported events are:
	#  - composition:save
	on: (ev, callback) ->
		evs   = ev.split(' ')
		calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}
		for name in evs
			calls[name] or= []
			calls[name].push(callback)
		@

	# Unbind an event listener
	off: (ev, callback) ->	
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
	_trigger: (args...) ->
		ev = args.shift()
		list = @hasOwnProperty('_callbacks') and @_callbacks?[ev]
		return unless list
		for callback in list
			if callback.apply(@, args) is false
				break
		true

	# Send a message to the plugin iframe
	# 
	# @private
	_sendMessage: (message) ->
		@_queue.defer (next) =>
			@frame.postMessage JSON.stringify(message), '*'
			next()

	# Called when the plugin iframe is ready, starts processing the queue
	# 
	# @private
	_ready: -> 
		Widgetic.debug.timestamp 'Widgetic.UI.Plugin:_ready'
		@_startQueue()

	# Called when the access token is updated (channel: api/token/update)
	# Updates the plugin's token
	# 
	# @private
	_updateToken: -> 
		Widgetic.debug.timestamp 'Widgetic.UI.Plugin:_updateToken'
		@_sendMessage t: 'token', d: api.accessToken()

module.exports = Plugin