api 	= Blogvio.require 'blogvio/api/index'
config 	= Blogvio.require 'blogvio/config'
queue 	= Blogvio.require 'blogvio/utils/queue'
describe 'blogvio/api/request', ->
	jasmine.Ajax.install()
	jasmine.Ajax.stubRequest('success?').andReturn({status:200,responseText:'{"success":true}'});
	jasmine.Ajax.stubRequest('fail?').andReturn({status:401,responseText:'{"success":false}'});
	
	beforeEach ->
		@post_parent = jasmine.createSpy 'post_parent'
		@parent = {postMessage:@post_parent}
		JSON  	= Blogvio.JSON

	it 'does a successfull request and posts back the result', ->
		window.parent = @parent
		api.request({id:'1',a:{u:'success',m:"GET",d:{}}})
		expect(@post_parent).toHaveBeenCalled()

		message = JSON.parse(@post_parent.mostRecentCall.args[0])
		expect(message.t).toEqual('e')
		expect(message.id).toEqual('1')
		expect(message.a.t).toEqual('t')
		expect(message.a.d).toEqual '{"success":true}'

	it 'does a failling request and posts back the result', ->
		window.parent = @parent
		api.request({id:'3',a:{u:'fail',m:"GET",d:{}}})
		expect(@post_parent).toHaveBeenCalled()

		message = JSON.parse(@post_parent.mostRecentCall.args[0])
		expect(message.t).toEqual('e')
		expect(message.id).toEqual('3')
		expect(message.a.t).toEqual('f')
		expect(message.a.d).toEqual '{"success":false}'

describe 'blogvio/api', ->
	queue.steps.init?()
	queue.steps.init= null
	beforeEach ->
		JSON = Blogvio.JSON
		@post = jasmine.createSpy 'post'
		api.setProxy @post
		api.setTokens {access_token:'xyz'}
		
	it 'post message with request data to proxy', ->
		api('users')
		expect(@post).toHaveBeenCalled()
		message = JSON.parse(@post.mostRecentCall.args[0])
		expect(message.id).toBeDefined()
		expect(message.t).toEqual 'a'
		expect(message.a).toBeTruthy()
		expect(message.a.u).toEqual(config.api+'users')
		expect(message.a.m).toEqual('GET')
		expect(message.a.d.access_token).toEqual('xyz')