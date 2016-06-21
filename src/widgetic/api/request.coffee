uxhr 	= require 'uxhr'
json	= require 'json3'
config 	= require '../config'

request = (params)->
	return unless params.id and a=(params.a)

	url  		= a.u
	method  	= a.m
	data 		= a.d
	message 	= {id:params.id,t:'e',a:{}}

	headers = {"Content-type":"application/json"}

	if (method = method.toUpperCase()) is 'PUT' or method is "DELETE"
		headers['X-HTTP-Method-Override'] = method
		method = "POST"

	complete = (response,status)->
		message.a.t = if status in [200, 201, 202, 204] then 't' else 'f'
		message.a.d = response
		message 	= json.stringify message
		# TODO: set targetOrigin
		if config.crossdomain
			window.parent.postMessage message, '*'
		else
			window.widgeticReceiver {origin: window.location.origin, data: message}

	settings = {method,headers,complete}
	uxhr url, data, settings

module.exports 	= request
