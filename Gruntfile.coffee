proxySnippet 	= require('grunt-connect-proxy/lib/utils').proxyRequest
mountFolder  	= (connect, dir)->connect.static(require('path').resolve(dir))
module.exports 	= (grunt)->
	grunt.loadNpmTasks 'grunt-karma'
	grunt.loadNpmTasks 'grunt-bump'
	grunt.loadNpmTasks 'grunt-browserify'
	grunt.loadNpmTasks 'grunt-contrib-uglify'
	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.initConfig(
		pkg: grunt.file.readJSON 'package.json'
		bump: 
			options: 
				files: ['package.json', 'bower.json'],
				updateConfigs: ['pkg'],
				commit: true,
				commitMessage: 'Release v%VERSION%',
				commitFiles: ['package.json', 'bower.json', 'lib/sdk.js']
				createTag: true
				tagName: '%VERSION%'
				tagMessage: 'Version %VERSION%'
				push: false
		replace:
			version:
				src: ['lib/sdk.js'],
				overwrite: true,
				replacements: [{
					from: /@VERSION/g,
					to: "<%= pkg.version %>"
				}]
		browserify:
			js:
				dest: 'lib/sdk.js'
				src:['src/index.coffee']
				options:
					transform: ['coffeeify','debowerify']
					extensions:['.coffee']
					external: ['spine/utils/timestamp']
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
		watch:
			js:
				files: ['src/**/*.coffee']
				tasks: ['notify:start_build', 'browserify', 'notify:finish_build']
		notify:
			start_build:
				options:
					enabled: true
					title: "Watch."
					message: 'Build started.'
			finish_build:
				options:
					enabled: true
					title: "Watch."
					message: 'Build finished.'
		connect:
			options:
				port:8082
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
	grunt.loadNpmTasks 'grunt-notify'
	grunt.loadNpmTasks 'grunt-contrib-connect'
	grunt.loadNpmTasks 'grunt-connect-proxy'
	grunt.loadNpmTasks 'grunt-text-replace'

	grunt.registerTask 'build',         ['browserify']
	grunt.registerTask 'build-release', ['build','uglify']
	grunt.registerTask 'release',       ['build-release', 'bump-only', 'replace:version', 'bump-commit']
	grunt.registerTask 'test',          ['karma']
	grunt.registerTask 'server',        ['configureProxies','connect:server']
	grunt.registerTask 'default',       ['build']