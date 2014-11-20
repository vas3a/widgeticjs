config  = require '../config'
request = require './request'
queue   = require '../utils/queue'
guid    = require '../utils/guid'

aye     = require 'aye'
json    = require 'json3'
pubsub  = require 'pubsub.js'


defs 	= {}
link    = {}
tokenDef= null
tknDelay=null
init    = false

prepare_message = (url,method,data,id) ->
	url = config.api + url
	access_token = link.tokens?.access_token or false 
	if (method or= 'GET') instanceof Object
		data = method
		method = 'GET'

	if method  isnt 'GET'
		url =  url + if access_token then "?access_token=#{access_token}" else ''
	else
		data or= {}
		if access_token
			data.access_token = access_token

	json.stringify {t:"a",id:id,a:{u:url,m:method,d:data}}

api = (url,method,data) ->
	# TODO: reject the promise if not authorized
	id 	= guid()
	promise = (defs[id] = deffered = aye.defer()).promise
	queue.defer (next) =>
		message = prepare_message.apply @, deffered.margs = [url,method, data, id]
		promise.then advance=(->defs[id] = null or next()),advance
		link.proxy message
	promise

api.response = (message) ->
	deffered = defs[message.id]
	a        = message.a
	data     = a.d

	if data isnt ""
		try
			data = json.parse(data)
		catch
			deffered.reject  "JSON Parse error!"
			return

	if a.t is 't'
		deffered.resolve data
	else
		if data.error and data.error in ['invalid_grant', 'access_denied']
			# if there was an auth error, try authorizing again
			ok = -> tokenDef = null; link.proxy prepare_message.apply @, deffered.margs
			requestToken().then ok, (-> tokenDef = null; deffered.reject 'Unable to login again!')
		else
			deffered.reject data

requestToken = ->
	return (require '../auth/index')(false) unless init

	promise = (tokenDef = aye.defer()).promise
	message = json.stringify {t: 'r', d: [false]}
	window.parent.postMessage message, config.lo
	tknDelay = setTimeout tokenDef.reject, 3000
	promise

api.setProxy = (proxy) -> link.proxy = proxy

api.setTokens = (tokens) ->
	init = true
	link.tokens = tokens
	pubsub.publish 'api/token/update'

api.getStatus = -> 
	if link.tokens?.access_token
		return {
			status: 'connected',
			accessToken: link.tokens.access_token
			expiresIn: link.tokens.expires_in
			scope: link.tokens.scope
		}
	else
		return { status: 'disconnected'}

api.accessToken = (token) -> 
	if token
		clearTimeout tknDelay
		tokenDef?.resolve token

		api.setTokens {
			access_token: token
			expires_in: undefined
			scope: undefined
		}
	
	link.tokens?.access_token

api.disconnect = ->	
	# TODO: invalidate the token
	pubsub.publish 'api/token/update'
	link.tokens = null

api.queue 		= queue
api.request 	= request
module.exports  = api