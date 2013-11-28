uxhr 	= require 'uxhr'
json	= require 'json3'

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
	if method is "POST"
		data = json.stringify(data)
	complete = (response,status)->
		message.a.t = if status is 200 then 't' else 'f'
		message.a.d = response
		message 	= json.stringify message
		window.parent.postMessage message, '*'

	settings = {method,headers,complete}	
	uxhr url, data, settings

module.exports 	= request