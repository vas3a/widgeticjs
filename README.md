# Client Library for the [Widgetic](https://widgetic.com) API

This is a JavaScript client library for the Widgetic API,
[written in CoffeeScript](http://coffeescript.org/), suitable for use in most
browsers.

##Installation

### In the browser

This library is available at https://widgetic.com/sdk/sdk.js
so add  the following `script` tag in the `head` section of your page:

```html
<script type="text/javascript" src="https://widgetic.com/sdk/sdk.js"></script>
```

## Usage

The documentation is available on the [Widgetic Documentation website](http://docs.widgetic.com).

The library exposes a global `Widgetic` variable that you can use to interact with the SDK's functions.

The first step is to initialize the SDK with your Widgetic app_id and redirect_url:
```js
Widgetic.init('<app_id here>','<redirect_url here>');
```

After this step you can login using the `Widgetic.auth()` function.

You can pass a `Boolean` parameter that indicates if a popup should be opened or you just want to check if user is logged in. Default will open popup.

This has promise support built-in using the [aye](https://github.com/cburgmer/ayepromise) library.
```js
//Check if user is logged in
Widgetic.auth(false).then(function(){/*handle success*/},function(){/*handle fail*/});
//Open popup to login user
Widgetic.auth().then(function(){/*handle success*/},function(){/*handle fail*/});
```

After user is logged in you call the Widgetic API using `Widgetic.api(url,method,data)`.
This function returns a promise.
For example if you want to grab user info:

```js
Widgetic.api('users/me').then(function(data){/*handle success*/},function(error){/*handle fail*/});
```
