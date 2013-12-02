# Client Library for the [Blogvio](http://blogvio.com) API

This is a JavaScript client library for the Blogvio API,
[written in CoffeeScript](http://coffeescript.org/), suitable for use in most
browsers.

[![Build Status](https://secure.travis-ci.org/blogvio/blogviojs.png?branch=master)](http://travis-ci.org/blogvio/blogviojs)
##Installation
The source is available for download from
[GitHub](http://github.com/blogvio/blogviojs).
Alternatively, you can install using Node Package Manager (npm) or using Bower Package Manager (bower).
### In the browser
This library will be available at http://blogvio.com/sdk/sdk.js
so add  the following `script` tag in the `head` section of your page:
```html
<script type="text/javascript" src="http://blogvio.com/sdk/sdk.js"></script>
 ```
### Package Managers
#### Npm
If you don't have `node` or `npm` installed go to http://nodejs.org/ and install it.
After the installation run the following command in your project's directory:
```
npm install blogviojs
 ```
The package will be available in **node_modules/blogviojs**.
####Bower
If you don't have `bower` installed follow the guide at http://bower.io/ to install it then run the following command in your project's directory:
```
bower install blogviojs
```
The package will be available in your defined bower folder.

##Usage
After installing the library in your page you can use the Blogvio SDK.

The library exposes a global `Blogvio` variable that you can use to interact with the SDK's functions.

The first step is to initialize the SDK with your Blogvio app_id and redirect_url:
```js
Blogvio.init('<app_id here>','<redirect_url here>');
```

After this step you can login using the `Blogvio.auth()` function.

You can pass a `Boolean` parameter that indicates if a popup should be opened or you just want to check if user is logged in. Default will open popup.

This has promise support built-in using the [aye](https://github.com/cburgmer/ayepromise) library.
```js
//Check if user is logged in
Blogio.auth(false).then(function(){/*handle success*/},function(){/*handle fail*/});
//Open popup to login user
Blogio.auth().then(function(){/*handle success*/},function(){/*handle fail*/});
```

After user is logged in you call the Blogvio API using `Blogvio.api(url,method,data)`.
This function returns a promise.
For example if you want to grab user info:
```js
//Grab user info
Blogio.api('users/me').then(function(data){/*handle success*/},function(error){/*handle fail*/});
```
