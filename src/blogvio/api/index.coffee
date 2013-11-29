config 	 = require '../config'
request  = require './request'
auth 	 = require '../auth/index'
queue 	 = require '../utils/queue'
guid	 = require '../utils/guid'

aye 	 = require 'aye'
json	 = require 'json3'


defs 	= {}
link = {}

prepare_message = (url,method,data,id)->
	url = config.api + url

	if (method or= 'GET') instanceof Object
		data = method
		method = 'GET'

	if method  isnt 'GET'
		url = "#{url}?access_token=#{link.tokens.access_token}"
	else
		data or= {}
		if link.tokens?.access_token
			data.access_token = link.tokens.access_token

	json.stringify {t:"a",id:id,a:{u:url,m:method,d:data}}

api 	= (url,method,data)->
	id 	= guid()
	promise = (defs[id] = deffered = aye.defer()).promise
	queue.defer (next)=>
		message = prepare_message.apply @, deffered.margs = [url,method, data, id]
		promise.then advance=(->defs[id] = null or next()),advance
		link.proxy message
	promise

api.response 	= (message)->
	deffered = defs[id = message.id]
	a 	 	 = message.a
	data	 = a.d

	try
		data = json.parse(data)
	catch
		deffered.reject  "JSON Parse error!"
		return

	if a.t is 't'
		deffered.resolve data
	else
		if data.error and data.error is 'invalid_grant'
			ok = ->link.proxy( prepare_message.apply @, deffered.margs )
			auth(false).then ok,(->deffered.reject 'Unable to login again!')
		else
			deffered.reject data

api.setProxy = (proxy)->link.proxy = proxy
api.setTokens = (tokens)->link.tokens = tokens

api.queue 		= queue
api.request 	= request
module.exports  = api