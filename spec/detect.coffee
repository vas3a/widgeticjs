detect 	= Blogvio.require 'detect/index'
parse  	= detect.parse

describe 'blogvio/detect', ->
	beforeEach ->
		@post_parent = jasmine.createSpy 'post_parent'
		@post_opener = jasmine.createSpy 'post_opener'

		@parent = {postMessage:@post_parent}
		@opener = {postMessage:@post_opener}
		JSON  	= Blogvio.JSON

	it 'parses url', ->
		url 	= "http://blogvio.com?error=0&error_message=1#token=2&refresh=no"
		parsed 	= parse(url)
		expect(parsed.query).toEqual('error=0&error_message=1')
		expect(parsed.queryKey.error).toEqual('0')
		expect(parsed.queryKey.error_message).toEqual('1')
		expect(parsed.hash).toEqual('token=2&refresh=no')
		expect(parsed.hashKey.token).toEqual('2')
		expect(parsed.hashKey.refresh).toEqual('no')

	it 'does nothing if not in iframe or popup',->
		window.opener = null
		window.parent = window
		spyOn window.parent,'postMessage'
		detect('http://blogvio.com/proxy#proxy')
		detect("http://blogvio.com/popup#access_token=xyz&token_type=bearer")
		detect("http://blogvio.com/popup?error=xyz&error_message=bearer")
		expect(window.parent.postMessage).not.toHaveBeenCalled()

	it 'initializes proxy', ->
		window.parent = @parent
		window.opener = null
		detect('http://blogvio.com/proxy#prox')
		expect(@post_parent).not.toHaveBeenCalled()
		detect('http://blogvio.com/proxy#proxy')
		expect(@post_parent).toHaveBeenCalled()
		expect(@post_parent.mostRecentCall.args[0]).toEqual('{"t":"i"}')
		expect(@post_parent.mostRecentCall.args[1]).toEqual('*')

	it 'grabs access token from popup',->
		window.parent = window
		window.opener = @opener
		detect("http://blogvio.com/popup#access_token=xyz&token_type=bearer")
		expect(@post_opener).toHaveBeenCalled()
		expect(@post_parent).not.toHaveBeenCalled()

		posted  = JSON.parse(@post_opener.mostRecentCall.args[0])

		expect(posted.t).toEqual 'o'
		expect(posted.d.access_token).toEqual 'xyz'
		expect(posted.d.token_type).toEqual 'bearer'

	it 'grabs access token from iframe', ->
		window.parent = @parent
		window.opener = null
		detect("http://blogvio.com/otherpopup#access_token=xyz&token_type=bearer")
		expect(@post_opener).not.toHaveBeenCalled()
		expect(@post_parent).toHaveBeenCalled()

		posted  = JSON.parse(@post_parent.mostRecentCall.args[0])

		expect(posted.t).toEqual 'o'
		expect(posted.d.access_token).toEqual 'xyz'
		expect(posted.d.token_type).toEqual 'bearer'

	it 'grabs query string error from popup', ->
		window.parent = window
		window.opener = @opener
		detect("http://blogvio.com/otherpopup?error=xyz&error_description=desc")
		expect(@post_opener).toHaveBeenCalled()
		expect(@post_parent).not.toHaveBeenCalled()

		posted  = JSON.parse(@post_opener.mostRecentCall.args[0])
		
		expect(posted.t).toEqual 'o'
		expect(posted.d.access_token).toBeUndefined()
		expect(posted.d.error).toEqual 'xyz'
		expect(posted.d.error_description).toEqual 'desc'