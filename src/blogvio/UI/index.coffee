Composition = require './composition'
Editor = require './editor'

composition = ->
	new Composition arguments...

editor = ->
	new Editor arguments...

UI = {composition, editor}

module.exports = UI