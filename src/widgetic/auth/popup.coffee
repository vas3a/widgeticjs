aye 	= require 'aye'
guid 	= require '../utils/guid'
rwin 	= window

link 	= {}

options = (width,height)->
	left = (screen.width-width)/2
	top  = (screen.height-height)/2
	"location=no,menubar=no,toolbar=no,scrollbars=no,status=no,resizable=no,width=#{width},height=#{height},left=#{left},top=#{top}"

popup  = (url,deffered)->
	promise = deffered.promise

	link.win?.close()
	link.win = win = rwin.open url,"widgetic_popup_#{guid()}", options(500,496)

	check = ->
		if !win or win.closed
			clearInterval interval
			deffered.reject('window closed')

	interval = setInterval(check,50)

	promise.then(->win.close())
	promise
	
module.exports = popup