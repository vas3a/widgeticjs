config  = require '../config' 
api     = require '../api'

popup  	= require './popup'
iframe 	= require './iframe'

aye 	= require 'aye'

app 	= {}

link 	= {}

lastScope = []

url = (scope=[], hash='oauth')->
	"#{config.auth}?client_id=#{app.id}&redirect_uri=#{app.uri}&response_type=token&scope=#{scope.join ' '}##{hash}"

_get = (interactive=true, scope) ->
	deffered = aye.defer()
	
	oa = if interactive then popup else iframe

	# remember the last requested scope and use that if not provided
	# this allows automatic retry of `api` calls to succeed
	lastScope = scope if scope
	scope = lastScope
	
	link.deffered = deffered
	{oa, scope, deffered}

doAuth = (oa, url, deffered)->
	unless app.id and app.uri
		deffered.reject 'Widgetic must be initialized with client id and redirect uri!'
		return deffered.promise

	oa url, deffered

auth = ->
	{oa, scope, deffered} = _get arguments...
	doAuth oa, url(scope), deffered

auth.register = (scope) ->
	{oa, scope, deffered} = _get true, scope

	doAuth oa, url(scope, 'signup'), deffered

auth.setAuthOptions = (id,uri,root)->
	app.id = id
	app.uri = uri

auth.getClientId = -> app.id

auth.retry = (response) ->
	auth.apply @, response.d

auth.connect = (response)->
	data = response.d
	# try reauthenticating before the token expires
	if data and data.access_token
		api.setTokens data
		link.deffered.resolve api.getStatus()
		setTimeout auth.bind(@, false), data.expires_in*1000-1500
	else
		link.deffered.reject api.getStatus()

module.exports = auth