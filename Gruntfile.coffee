proxySnippet 	= require('grunt-connect-proxy/lib/utils').proxyRequest
mountFolder  	= (connect, dir)->connect.static(require('path').resolve(dir))
module.exports 	= (grunt)->
	grunt.loadNpmTasks 'grunt-karma'
	grunt.loadNpmTasks 'grunt-browserify'
	grunt.loadNpmTasks 'grunt-contrib-uglify'
	grunt.initConfig(
		browserify:
			js:
				dest: 'lib/sdk.js'
				src:['src/index.coffee']			
				options:
					transform: ['coffeeify','debowerify']
					extensions:['.coffee']
					aliasMappings:[
						{
							cwd:'src/blogvio',
							src: ['**/*.coffee'],
							dest: '.'
						}
					]
					postBundleCB:(err,src,next)->
						src = src.slice(8) if src
						next(err,src)
		uglify:
			js:
				files:
					"lib/sdk.js":['lib/sdk.js']
		karma:
			unit:
				configFile: 'karma.conf.js'
				background: false
		connect:
			options:
				port:80
				base:'lib'
				keepalive:true
				hostname:"*"
			proxies:[{
				context 		: '/api/v2'
				host			: 'staging.blogvio.com'
				changeOrigin	: true
			}]
			server:
				options:
					middleware:(connect)->[proxySnippet,mountFolder(connect,'./lib')]
	)
	grunt.loadNpmTasks 'grunt-contrib-connect'
	grunt.loadNpmTasks 'grunt-connect-proxy'

	grunt.registerTask 'build', 	['browserify']
	grunt.registerTask 'release',	['build','uglify']
	grunt.registerTask 'test', 		['karma']
	grunt.registerTask 'server',	['configureProxies','connect:server']
	grunt.registerTask 'default', 	['build']