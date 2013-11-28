queue = require('queue-async')(1)
steps = {}

nextInit = (next)->
	steps.init = next

queue.defer nextInit
queue.steps = steps

module.exports  = queue