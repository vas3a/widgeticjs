Composition = require './composition'
Editor = require './editor'
popup = require './popup'
parse = require './parse'

composition = ->
	new Composition arguments...

editor = ->
	new Editor arguments...

module.exports = {composition, editor, parse, popup}