add = 'addEventListener'
rem = 'removeEventListener'
module.exports =
	on : (el,type,fn,capture=false)->
		if el[add] then el[add](type,fn,capture) else el.attachEvent("on#{type}",fn)
	off:(el,type,fn,capture=false)->
		if el[rem] then el[rem](type,fn,capture) else el.detachEvent("on#{type}",fn)