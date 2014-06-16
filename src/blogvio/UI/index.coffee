Composition = require './composition'
Editor = require './editor'
parse = require './parse'

composition = ->
	new Composition arguments...

editor = ->
	new Editor arguments...

UI = {composition, editor, parse}

module.exports = UI