// Karma configuration
// Generated on Mon Oct 21 2013 11:25:45 GMT+0300 (GTB Daylight Time)

module.exports = function(config) {
  config.set({

    // base path, that will be used to resolve files and exclude
    basePath: '',


    // frameworks to use
    frameworks: ['jasmine'],


    // list of files / patterns to load in the browser
    files: [
        'bower/jasmine-ajax/lib/mock-ajax.js',
        {pattern: 'lib/**/*.js', included: true},
        'spec/*.coffee'
    ],


    // list of files to exclude
    exclude: [
      
    ],
    plugins:[
        "karma-jasmine",
        "karma-coffee-preprocessor",
        "karma-phantomjs-launcher",
        "karma-script-launcher"
    ],

    // test results reporter to use
    // possible values: 'dots', 'progress', 'junit', 'growl', 'coverage'
    reporters: [],


    // web server port
    port: 9876,


    // enable / disable colors in the output (reporters and logs)
    colors: true,


    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,


    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,


    // Start these browsers, currently available:
    // - Chrome
    // - ChromeCanary
    // - Firefox
    // - Opera
    // - Safari (only Mac)
    // - PhantomJS
    // - IE (only Windows)
    browsers: ['PhantomJS'],

    preprocessors : {
        '**/*.coffee': 'coffee'
    },
    // If browser does not capture in given timeout [ms], kill it
    captureTimeout: 60000,


    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: true
  });
};
