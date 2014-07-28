config  = require '../config' 
api     = require '../api'

popup  	= require './popup'
iframe 	= require './iframe'

aye 	= require 'aye'

app 	= {}

link 	= {}

lastScope = []

url = (scope=[])->
	"#{config.auth}?client_id=#{app.id}&redirect_uri=#{app.uri}&response_type=token&scope=#{scope.join ' '}#oauth"

auth = (interactive=true, scope) ->
	# TODO: reject the deffered immediately if not initialized
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
	if data and data.access_token
		api.setTokens data
		link.deffered.resolve api.getStatus()
	else
		link.deffered.reject api.getStatus()

module.exports = auth