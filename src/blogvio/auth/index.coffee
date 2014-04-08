config  = require '../config' 


popup  	= require './popup'
iframe 	= require './iframe'

aye 	= require 'aye'

app 	= {}

link 	= {}

lastScope = []

url = (scope=[])->
	"#{config.auth}?client_id=#{app.id}&redirect_uri=#{app.uri}&response_type=token&scope=#{scope.join ' '}"

auth = (interactive=true, scope) ->
	deffered = aye.defer()
	
	oa = if interactive  then popup else iframe

	# remember the last requested scope and use that if not provided
	# this allows automatic retry of `api` calls to succeed
	lastScope = scope if scope
	scope = lastScope
	
	link.deffered = deffered

	oa(url(scope),deffered)

auth.setAuthOptions = (id,uri,root)->
	app.id = id
	app.uri = uri

auth.connect = (response)->
	data = response.d
	if data and data.access_token and data.refresh_token
		require('../api/index').setTokens data
		link.deffered.resolve("was ok")
	else
		link.deffered.reject "auth fail"

module.exports = auth