Composition = require './composition'
Editor = require './editor'
plugin = require './plugin'
popup = require './popup'
parse = require './parse'

composition = ->
	new Composition arguments...

editor = ->
	new Editor arguments...

module.exports = {Composition, Editor, composition, editor, parse, popup, plugin}