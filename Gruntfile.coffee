proxySnippet 	= require('grunt-connect-proxy/lib/utils').proxyRequest
mountFolder  	= (connect, dir)->connect.static(require('path').resolve(dir))
module.exports 	= (grunt)->
	grunt.loadNpmTasks 'grunt-karma'
	grunt.loadNpmTasks 'grunt-bump'
	grunt.loadNpmTasks 'grunt-browserify'
	grunt.loadNpmTasks 'grunt-contrib-uglify'
	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-groundskeeper'
	grunt.loadNpmTasks 'grunt-contrib-copy'
	grunt.initConfig(
		pkg: grunt.file.readJSON 'package.json'
		groundskeeper:
			compile:
				files:
					'lib/sdk.js': 'lib/sdk.dev.js'
				options: 
					console: false
					namespace: ['Blogvio.debug']
		bump: 
			options: 
				files: ['package.json', 'bower.json'],
				updateConfigs: ['pkg'],
				commit: true,
				commitMessage: 'Release v%VERSION%',
				commitFiles: ['package.json', 'bower.json', 'lib/sdk.js', 'lib/sdk.dev.js']
				createTag: true
				tagName: '%VERSION%'
				tagMessage: 'Version %VERSION%'
				push: false
		replace:
			version:
				src: ['lib/sdk.dev.js', 'lib/sdk.js'],
				overwrite: true,
				replacements: [{
					from: /@VERSION/g,
					to: "<%= pkg.version %>"
				}]
		browserify:
			js:
				dest: 'lib/sdk.dev.js'
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
		copy:
			js:
				src: 'lib/sdk.dev.js'
				dest: 'lib/sdk.js'
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
				tasks: ['notify:start_build', 'browserify', 'copy', 'notify:finish_build']
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
        			protocol: 'https'
					middleware:(connect)->[proxySnippet,mountFolder(connect,'./lib')]
	)
	grunt.loadNpmTasks 'grunt-notify'
	grunt.loadNpmTasks 'grunt-contrib-connect'
	grunt.loadNpmTasks 'grunt-connect-proxy'
	grunt.loadNpmTasks 'grunt-text-replace'

	grunt.registerTask 'build',         ['browserify', 'copy']
	grunt.registerTask 'build-release', ['build', 'groundskeeper', 'uglify']
	grunt.registerTask 'release',       ['release:minor']
	grunt.registerTask 'release:patch', ['build-release', 'bump-only:patch', 'replace:version', 'bump-commit']
	grunt.registerTask 'release:minor', ['build-release', 'bump-only:minor', 'replace:version', 'bump-commit']
	grunt.registerTask 'release:major', ['build-release', 'bump-only:major', 'replace:version', 'bump-commit']
	grunt.registerTask 'test',          ['karma']
	grunt.registerTask 'server',        ['configureProxies','connect:server']
	grunt.registerTask 'default',       ['build']