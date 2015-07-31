(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
// UMD header
(function (root, factory) {
    if (typeof define === 'function' && define.amd) {
        define(factory);
    } else if (typeof exports === 'object') {
        module.exports = factory();
    } else {
        root.ayepromise = factory();
    }
}(this, function () {
    'use strict';

    var ayepromise = {};

    /* Wrap an arbitrary number of functions and allow only one of them to be
       executed and only once */
    var once = function () {
        var wasCalled = false;

        return function wrapper(wrappedFunction) {
            return function () {
                if (wasCalled) {
                    return;
                }
                wasCalled = true;
                wrappedFunction.apply(null, arguments);
            };
        };
    };

    var getThenableIfExists = function (obj) {
        // Make sure we only access the accessor once as required by the spec
        var then = obj && obj.then;

        if (typeof obj === "object" && typeof then === "function") {
            // Bind function back to it's object (so fan's of 'this' don't get sad)
            return function() { return then.apply(obj, arguments); };
        }
    };

    var aThenHandler = function (onFulfilled, onRejected) {
        var defer = ayepromise.defer();

        var doHandlerCall = function (func, value) {
            setTimeout(function () {
                var returnValue;
                try {
                    returnValue = func(value);
                } catch (e) {
                    defer.reject(e);
                    return;
                }

                if (returnValue === defer.promise) {
                    defer.reject(new TypeError('Cannot resolve promise with itself'));
                } else {
                    defer.resolve(returnValue);
                }
            }, 1);
        };

        var callFulfilled = function (value) {
            if (onFulfilled && onFulfilled.call) {
                doHandlerCall(onFulfilled, value);
            } else {
                defer.resolve(value);
            }
        };

        var callRejected = function (value) {
            if (onRejected && onRejected.call) {
                doHandlerCall(onRejected, value);
            } else {
                defer.reject(value);
            }
        };

        return {
            promise: defer.promise,
            handle: function (state, value) {
                if (state === FULFILLED) {
                    callFulfilled(value);
                } else {
                    callRejected(value);
                }
            }
        };
    };

    // States
    var PENDING = 0,
        FULFILLED = 1,
        REJECTED = 2;

    ayepromise.defer = function () {
        var state = PENDING,
            outcome,
            thenHandlers = [];

        var doSettle = function (settledState, value) {
            state = settledState;
            // persist for handlers registered after settling
            outcome = value;

            thenHandlers.forEach(function (then) {
                then.handle(state, outcome);
            });

            // Discard all references to handlers to be garbage collected
            thenHandlers = null;
        };

        var doFulfill = function (value) {
            doSettle(FULFILLED, value);
        };

        var doReject = function (error) {
            doSettle(REJECTED, error);
        };

        var registerThenHandler = function (onFulfilled, onRejected) {
            var thenHandler = aThenHandler(onFulfilled, onRejected);

            if (state === PENDING) {
                thenHandlers.push(thenHandler);
            } else {
                thenHandler.handle(state, outcome);
            }

            return thenHandler.promise;
        };

        var safelyResolveThenable = function (thenable) {
            // Either fulfill, reject or reject with error
            var onceWrapper = once();
            try {
                thenable(
                    onceWrapper(transparentlyResolveThenablesAndSettle),
                    onceWrapper(doReject)
                );
            } catch (e) {
                onceWrapper(doReject)(e);
            }
        };

        var transparentlyResolveThenablesAndSettle = function (value) {
            var thenable;

            try {
                thenable = getThenableIfExists(value);
            } catch (e) {
                doReject(e);
                return;
            }

            if (thenable) {
                safelyResolveThenable(thenable);
            } else {
                doFulfill(value);
            }
        };

        var onceWrapper = once();
        return {
            resolve: onceWrapper(transparentlyResolveThenablesAndSettle),
            reject: onceWrapper(doReject),
            promise: {
                then: registerThenHandler,
                fail: function (onRejected) {
                    return registerThenHandler(null, onRejected);
                }
            }
        };
    };

    return ayepromise;
}));

},{}],2:[function(require,module,exports){
/**
 * pubsub.js
 *
 * A tiny, optimized, tested, standalone and robust
 * pubsub implementation supporting different javascript environments
 *
 * @author Federico "Lox" Lucignano <http://plus.ly/federico.lox>
 *
 * @see https://github.com/federico-lox/pubsub.js
 */

/*global define, module*/
(function (context) {
	'use strict';

	/**
	 * @private
	 */
	function init() {
		//the channel subscription hash
		var channels = {},
			//help minification
			funcType = Function;

		return {
			/*
			 * @public
			 *
			 * Publish some data on a channel
			 *
			 * @param String channel The channel to publish on
			 * @param Mixed argument The data to publish, the function supports
			 * as many data parameters as needed
			 *
			 * @example Publish stuff on '/some/channel'.
			 * Anything subscribed will be called with a function
			 * signature like: function(a,b,c){ ... }
			 *
			 * PubSub.publish(
			 *		"/some/channel", "a", "b",
			 *		{total: 10, min: 1, max: 3}
			 * );
			 */
			publish: function () {
				//help minification
				var args = arguments,
					// args[0] is the channel
					subs = channels[args[0]],
					len,
					params,
					x;

				if (subs) {
					len = subs.length;
					params = (args.length > 1) ?
							Array.prototype.splice.call(args, 1) : [];

					//run the callbacks asynchronously,
					//do not block the main execution process
					setTimeout(
						function () {
							//executes callbacks in the order
							//in which they were registered
							for (x = 0; x < len; x += 1) {
								subs[x].apply(context, params);
							}

							//clear references to allow garbage collection
							subs = context = params = null;
						},
						0
					);
				}
			},

			/*
			 * @public
			 *
			 * Register a callback on a channel
			 *
			 * @param String channel The channel to subscribe to
			 * @param Function callback The event handler, any time something is
			 * published on a subscribed channel, the callback will be called
			 * with the published array as ordered arguments
			 *
			 * @return Array A handle which can be used to unsubscribe this
			 * particular subscription
			 *
			 * @example PubSub.subscribe(
			 *				"/some/channel",
			 *				function(a, b, c){ ... }
			 *			);
			 */
			subscribe: function (channel, callback) {
				if (typeof channel !== 'string') {
					throw "invalid or missing channel";
				}

				if (!(callback instanceof funcType)) {
					throw "invalid or missing callback";
				}

				if (!channels[channel]) {
					channels[channel] = [];
				}

				channels[channel].push(callback);

				return {channel: channel, callback: callback};
			},

			/*
			 * @public
			 *
			 * Disconnect a subscribed function f.
			 *
			 * @param Mixed handle The return value from a subscribe call or the
			 * name of a channel as a String
			 * @param Function callback [OPTIONAL] The event handler originaally
			 * registered, not needed if handle contains the return value
			 * of subscribe
			 *
			 * @example
			 * var handle = PubSub.subscribe("/some/channel", function(){});
			 * PubSub.unsubscribe(handle);
			 *
			 * or
			 *
			 * PubSub.unsubscribe("/some/channel", callback);
			 */
			unsubscribe: function (handle, callback) {
				if (handle.channel && handle.callback) {
					callback = handle.callback;
					handle = handle.channel;
				}

				if (typeof handle !== 'string') {
					throw "invalid or missing channel";
				}

				if (!(callback instanceof funcType)) {
					throw "invalid or missing callback";
				}

				var subs = channels[handle],
					x,
					y = (subs instanceof Array) ? subs.length : 0;

				for (x = 0; x < y; x += 1) {
					if (subs[x] === callback) {
						subs.splice(x, 1);
						break;
					}
				}
			}
		};
	}

	//UMD
	if (typeof define === 'function' && define.amd) {
		//AMD module
		define('pubsub', init);
	} else if (typeof module === 'object' && module.exports) {
		//CommonJS module
		module.exports = init();
	} else {
		//traditional namespace
		context.PubSub = init();
	}
}(this));
},{}],3:[function(require,module,exports){
(function() {
  var slice = [].slice;

  function queue(parallelism) {
    var q,
        tasks = [],
        started = 0, // number of tasks that have been started (and perhaps finished)
        active = 0, // number of tasks currently being executed (started but not finished)
        remaining = 0, // number of tasks not yet finished
        popping, // inside a synchronous task callback?
        error = null,
        await = noop,
        all;

    if (!parallelism) parallelism = Infinity;

    function pop() {
      while (popping = started < tasks.length && active < parallelism) {
        var i = started++,
            t = tasks[i],
            a = slice.call(t, 1);
        a.push(callback(i));
        ++active;
        t[0].apply(null, a);
      }
    }

    function callback(i) {
      return function(e, r) {
        --active;
        if (error != null) return;
        if (e != null) {
          error = e; // ignore new tasks and squelch active callbacks
          started = remaining = NaN; // stop queued tasks from starting
          notify();
        } else {
          tasks[i] = r;
          if (--remaining) popping || pop();
          else notify();
        }
      };
    }

    function notify() {
      if (error != null) await(error);
      else if (all) await(error, tasks);
      else await.apply(null, [error].concat(tasks));
    }

    return q = {
      defer: function() {
        if (!error) {
          tasks.push(arguments);
          ++remaining;
          pop();
        }
        return q;
      },
      await: function(f) {
        await = f;
        all = false;
        if (!remaining) notify();
        return q;
      },
      awaitAll: function(f) {
        await = f;
        all = true;
        if (!remaining) notify();
        return q;
      }
    };
  }

  function noop() {}

  queue.version = "1.0.7";
  if (typeof define === "function" && define.amd) define(function() { return queue; });
  else if (typeof module === "object" && module.exports) module.exports = queue;
  else this.queue = queue;
})();

},{}],4:[function(require,module,exports){
(function (root, factory) {
	if (typeof exports === 'object') {
		module.exports = factory();
	} else if (typeof define === 'function' && define.amd) {
		define('uxhr', factory);
	} else {
		root.uxhr = factory();
	}
}(this, function () {

	"use strict";

	return function (url, data, options) {

		data = data || '';
		options = options || {};

		var complete = options.complete || function(){},
			success = options.success || function(){},
			error = options.error || function(){},
			headers = options.headers || {},
			method = options.method || 'GET',
			sync = options.sync || false,
			req = (function() {

				if (typeof 'XMLHttpRequest' !== 'undefined') {

					// CORS (IE8-9)
					if (url.indexOf('http') === 0 && typeof XDomainRequest !== 'undefined') {
						return new XDomainRequest();
					}

					// local, CORS (other browsers)
					return new XMLHttpRequest();

				} else if (typeof 'ActiveXObject' !== 'undefined') {
					return new ActiveXObject('Microsoft.XMLHTTP');
				}

			})();

		if (!req) {
			throw new Error ('Browser doesn\'t support XHR');
		}

		// serialize data?
		if (typeof data !== 'string') {
			var serialized = [];
			for (var datum in data) {
				serialized.push(datum + '=' + data[datum]);
			}
			data = serialized.join('&');
		}

		// set timeout
		if ('ontimeout' in req) {
			req.ontimeout = +options.timeout || 0;
		}

		// listen for XHR events
		req.onload = function () {
			complete(req.responseText, req.status);
			success(req.responseText);
		};
		req.onerror = function () {
			complete(req.responseText);
			error(req.responseText, req.status);
		};

		// open connection
		req.open(method, (method === 'GET' && data ? url+'?'+data : url), !sync);

		// set headers
		for (var header in headers) {
			req.setRequestHeader(header, headers[header]);
		}

		// send it
		req.send(method !== 'GET' ? data : null);

		return req;
	};

}));

},{}],5:[function(require,module,exports){
/*! JSON v3.2.6 | http://bestiejs.github.io/json3 | Copyright 2012-2013, Kit Cambridge | http://kit.mit-license.org */
;(function (window) {
  // Convenience aliases.
  var getClass = {}.toString, isProperty, forEach, undef;

  // Detect the `define` function exposed by asynchronous module loaders. The
  // strict `define` check is necessary for compatibility with `r.js`.
  var isLoader = typeof define === "function" && define.amd;

  // Detect native implementations.
  var nativeJSON = typeof JSON == "object" && JSON;

  // Set up the JSON 3 namespace, preferring the CommonJS `exports` object if
  // available.
  var JSON3 = typeof exports == "object" && exports && !exports.nodeType && exports;

  if (JSON3 && nativeJSON) {
    // Explicitly delegate to the native `stringify` and `parse`
    // implementations in CommonJS environments.
    JSON3.stringify = nativeJSON.stringify;
    JSON3.parse = nativeJSON.parse;
  } else {
    // Export for web browsers, JavaScript engines, and asynchronous module
    // loaders, using the global `JSON` object if available.
    JSON3 = window.JSON = nativeJSON || {};
  }

  // Test the `Date#getUTC*` methods. Based on work by @Yaffle.
  var isExtended = new Date(-3509827334573292);
  try {
    // The `getUTCFullYear`, `Month`, and `Date` methods return nonsensical
    // results for certain dates in Opera >= 10.53.
    isExtended = isExtended.getUTCFullYear() == -109252 && isExtended.getUTCMonth() === 0 && isExtended.getUTCDate() === 1 &&
      // Safari < 2.0.2 stores the internal millisecond time value correctly,
      // but clips the values returned by the date methods to the range of
      // signed 32-bit integers ([-2 ** 31, 2 ** 31 - 1]).
      isExtended.getUTCHours() == 10 && isExtended.getUTCMinutes() == 37 && isExtended.getUTCSeconds() == 6 && isExtended.getUTCMilliseconds() == 708;
  } catch (exception) {}

  // Internal: Determines whether the native `JSON.stringify` and `parse`
  // implementations are spec-compliant. Based on work by Ken Snyder.
  function has(name) {
    if (has[name] !== undef) {
      // Return cached feature test result.
      return has[name];
    }

    var isSupported;
    if (name == "bug-string-char-index") {
      // IE <= 7 doesn't support accessing string characters using square
      // bracket notation. IE 8 only supports this for primitives.
      isSupported = "a"[0] != "a";
    } else if (name == "json") {
      // Indicates whether both `JSON.stringify` and `JSON.parse` are
      // supported.
      isSupported = has("json-stringify") && has("json-parse");
    } else {
      var value, serialized = '{"a":[1,true,false,null,"\\u0000\\b\\n\\f\\r\\t"]}';
      // Test `JSON.stringify`.
      if (name == "json-stringify") {
        var stringify = JSON3.stringify, stringifySupported = typeof stringify == "function" && isExtended;
        if (stringifySupported) {
          // A test function object with a custom `toJSON` method.
          (value = function () {
            return 1;
          }).toJSON = value;
          try {
            stringifySupported =
              // Firefox 3.1b1 and b2 serialize string, number, and boolean
              // primitives as object literals.
              stringify(0) === "0" &&
              // FF 3.1b1, b2, and JSON 2 serialize wrapped primitives as object
              // literals.
              stringify(new Number()) === "0" &&
              stringify(new String()) == '""' &&
              // FF 3.1b1, 2 throw an error if the value is `null`, `undefined`, or
              // does not define a canonical JSON representation (this applies to
              // objects with `toJSON` properties as well, *unless* they are nested
              // within an object or array).
              stringify(getClass) === undef &&
              // IE 8 serializes `undefined` as `"undefined"`. Safari <= 5.1.7 and
              // FF 3.1b3 pass this test.
              stringify(undef) === undef &&
              // Safari <= 5.1.7 and FF 3.1b3 throw `Error`s and `TypeError`s,
              // respectively, if the value is omitted entirely.
              stringify() === undef &&
              // FF 3.1b1, 2 throw an error if the given value is not a number,
              // string, array, object, Boolean, or `null` literal. This applies to
              // objects with custom `toJSON` methods as well, unless they are nested
              // inside object or array literals. YUI 3.0.0b1 ignores custom `toJSON`
              // methods entirely.
              stringify(value) === "1" &&
              stringify([value]) == "[1]" &&
              // Prototype <= 1.6.1 serializes `[undefined]` as `"[]"` instead of
              // `"[null]"`.
              stringify([undef]) == "[null]" &&
              // YUI 3.0.0b1 fails to serialize `null` literals.
              stringify(null) == "null" &&
              // FF 3.1b1, 2 halts serialization if an array contains a function:
              // `[1, true, getClass, 1]` serializes as "[1,true,],". FF 3.1b3
              // elides non-JSON values from objects and arrays, unless they
              // define custom `toJSON` methods.
              stringify([undef, getClass, null]) == "[null,null,null]" &&
              // Simple serialization test. FF 3.1b1 uses Unicode escape sequences
              // where character escape codes are expected (e.g., `\b` => `\u0008`).
              stringify({ "a": [value, true, false, null, "\x00\b\n\f\r\t"] }) == serialized &&
              // FF 3.1b1 and b2 ignore the `filter` and `width` arguments.
              stringify(null, value) === "1" &&
              stringify([1, 2], null, 1) == "[\n 1,\n 2\n]" &&
              // JSON 2, Prototype <= 1.7, and older WebKit builds incorrectly
              // serialize extended years.
              stringify(new Date(-8.64e15)) == '"-271821-04-20T00:00:00.000Z"' &&
              // The milliseconds are optional in ES 5, but required in 5.1.
              stringify(new Date(8.64e15)) == '"+275760-09-13T00:00:00.000Z"' &&
              // Firefox <= 11.0 incorrectly serializes years prior to 0 as negative
              // four-digit years instead of six-digit years. Credits: @Yaffle.
              stringify(new Date(-621987552e5)) == '"-000001-01-01T00:00:00.000Z"' &&
              // Safari <= 5.1.5 and Opera >= 10.53 incorrectly serialize millisecond
              // values less than 1000. Credits: @Yaffle.
              stringify(new Date(-1)) == '"1969-12-31T23:59:59.999Z"';
          } catch (exception) {
            stringifySupported = false;
          }
        }
        isSupported = stringifySupported;
      }
      // Test `JSON.parse`.
      if (name == "json-parse") {
        var parse = JSON3.parse;
        if (typeof parse == "function") {
          try {
            // FF 3.1b1, b2 will throw an exception if a bare literal is provided.
            // Conforming implementations should also coerce the initial argument to
            // a string prior to parsing.
            if (parse("0") === 0 && !parse(false)) {
              // Simple parsing test.
              value = parse(serialized);
              var parseSupported = value["a"].length == 5 && value["a"][0] === 1;
              if (parseSupported) {
                try {
                  // Safari <= 5.1.2 and FF 3.1b1 allow unescaped tabs in strings.
                  parseSupported = !parse('"\t"');
                } catch (exception) {}
                if (parseSupported) {
                  try {
                    // FF 4.0 and 4.0.1 allow leading `+` signs and leading
                    // decimal points. FF 4.0, 4.0.1, and IE 9-10 also allow
                    // certain octal literals.
                    parseSupported = parse("01") !== 1;
                  } catch (exception) {}
                }
                if (parseSupported) {
                  try {
                    // FF 4.0, 4.0.1, and Rhino 1.7R3-R4 allow trailing decimal
                    // points. These environments, along with FF 3.1b1 and 2,
                    // also allow trailing commas in JSON objects and arrays.
                    parseSupported = parse("1.") !== 1;
                  } catch (exception) {}
                }
              }
            }
          } catch (exception) {
            parseSupported = false;
          }
        }
        isSupported = parseSupported;
      }
    }
    return has[name] = !!isSupported;
  }

  if (!has("json")) {
    // Common `[[Class]]` name aliases.
    var functionClass = "[object Function]";
    var dateClass = "[object Date]";
    var numberClass = "[object Number]";
    var stringClass = "[object String]";
    var arrayClass = "[object Array]";
    var booleanClass = "[object Boolean]";

    // Detect incomplete support for accessing string characters by index.
    var charIndexBuggy = has("bug-string-char-index");

    // Define additional utility methods if the `Date` methods are buggy.
    if (!isExtended) {
      var floor = Math.floor;
      // A mapping between the months of the year and the number of days between
      // January 1st and the first of the respective month.
      var Months = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
      // Internal: Calculates the number of days between the Unix epoch and the
      // first day of the given month.
      var getDay = function (year, month) {
        return Months[month] + 365 * (year - 1970) + floor((year - 1969 + (month = +(month > 1))) / 4) - floor((year - 1901 + month) / 100) + floor((year - 1601 + month) / 400);
      };
    }

    // Internal: Determines if a property is a direct property of the given
    // object. Delegates to the native `Object#hasOwnProperty` method.
    if (!(isProperty = {}.hasOwnProperty)) {
      isProperty = function (property) {
        var members = {}, constructor;
        if ((members.__proto__ = null, members.__proto__ = {
          // The *proto* property cannot be set multiple times in recent
          // versions of Firefox and SeaMonkey.
          "toString": 1
        }, members).toString != getClass) {
          // Safari <= 2.0.3 doesn't implement `Object#hasOwnProperty`, but
          // supports the mutable *proto* property.
          isProperty = function (property) {
            // Capture and break the object's prototype chain (see section 8.6.2
            // of the ES 5.1 spec). The parenthesized expression prevents an
            // unsafe transformation by the Closure Compiler.
            var original = this.__proto__, result = property in (this.__proto__ = null, this);
            // Restore the original prototype chain.
            this.__proto__ = original;
            return result;
          };
        } else {
          // Capture a reference to the top-level `Object` constructor.
          constructor = members.constructor;
          // Use the `constructor` property to simulate `Object#hasOwnProperty` in
          // other environments.
          isProperty = function (property) {
            var parent = (this.constructor || constructor).prototype;
            return property in this && !(property in parent && this[property] === parent[property]);
          };
        }
        members = null;
        return isProperty.call(this, property);
      };
    }

    // Internal: A set of primitive types used by `isHostType`.
    var PrimitiveTypes = {
      'boolean': 1,
      'number': 1,
      'string': 1,
      'undefined': 1
    };

    // Internal: Determines if the given object `property` value is a
    // non-primitive.
    var isHostType = function (object, property) {
      var type = typeof object[property];
      return type == 'object' ? !!object[property] : !PrimitiveTypes[type];
    };

    // Internal: Normalizes the `for...in` iteration algorithm across
    // environments. Each enumerated key is yielded to a `callback` function.
    forEach = function (object, callback) {
      var size = 0, Properties, members, property;

      // Tests for bugs in the current environment's `for...in` algorithm. The
      // `valueOf` property inherits the non-enumerable flag from
      // `Object.prototype` in older versions of IE, Netscape, and Mozilla.
      (Properties = function () {
        this.valueOf = 0;
      }).prototype.valueOf = 0;

      // Iterate over a new instance of the `Properties` class.
      members = new Properties();
      for (property in members) {
        // Ignore all properties inherited from `Object.prototype`.
        if (isProperty.call(members, property)) {
          size++;
        }
      }
      Properties = members = null;

      // Normalize the iteration algorithm.
      if (!size) {
        // A list of non-enumerable properties inherited from `Object.prototype`.
        members = ["valueOf", "toString", "toLocaleString", "propertyIsEnumerable", "isPrototypeOf", "hasOwnProperty", "constructor"];
        // IE <= 8, Mozilla 1.0, and Netscape 6.2 ignore shadowed non-enumerable
        // properties.
        forEach = function (object, callback) {
          var isFunction = getClass.call(object) == functionClass, property, length;
          var hasProperty = !isFunction && typeof object.constructor != 'function' && isHostType(object, 'hasOwnProperty') ? object.hasOwnProperty : isProperty;
          for (property in object) {
            // Gecko <= 1.0 enumerates the `prototype` property of functions under
            // certain conditions; IE does not.
            if (!(isFunction && property == "prototype") && hasProperty.call(object, property)) {
              callback(property);
            }
          }
          // Manually invoke the callback for each non-enumerable property.
          for (length = members.length; property = members[--length]; hasProperty.call(object, property) && callback(property));
        };
      } else if (size == 2) {
        // Safari <= 2.0.4 enumerates shadowed properties twice.
        forEach = function (object, callback) {
          // Create a set of iterated properties.
          var members = {}, isFunction = getClass.call(object) == functionClass, property;
          for (property in object) {
            // Store each property name to prevent double enumeration. The
            // `prototype` property of functions is not enumerated due to cross-
            // environment inconsistencies.
            if (!(isFunction && property == "prototype") && !isProperty.call(members, property) && (members[property] = 1) && isProperty.call(object, property)) {
              callback(property);
            }
          }
        };
      } else {
        // No bugs detected; use the standard `for...in` algorithm.
        forEach = function (object, callback) {
          var isFunction = getClass.call(object) == functionClass, property, isConstructor;
          for (property in object) {
            if (!(isFunction && property == "prototype") && isProperty.call(object, property) && !(isConstructor = property === "constructor")) {
              callback(property);
            }
          }
          // Manually invoke the callback for the `constructor` property due to
          // cross-environment inconsistencies.
          if (isConstructor || isProperty.call(object, (property = "constructor"))) {
            callback(property);
          }
        };
      }
      return forEach(object, callback);
    };

    // Public: Serializes a JavaScript `value` as a JSON string. The optional
    // `filter` argument may specify either a function that alters how object and
    // array members are serialized, or an array of strings and numbers that
    // indicates which properties should be serialized. The optional `width`
    // argument may be either a string or number that specifies the indentation
    // level of the output.
    if (!has("json-stringify")) {
      // Internal: A map of control characters and their escaped equivalents.
      var Escapes = {
        92: "\\\\",
        34: '\\"',
        8: "\\b",
        12: "\\f",
        10: "\\n",
        13: "\\r",
        9: "\\t"
      };

      // Internal: Converts `value` into a zero-padded string such that its
      // length is at least equal to `width`. The `width` must be <= 6.
      var leadingZeroes = "000000";
      var toPaddedString = function (width, value) {
        // The `|| 0` expression is necessary to work around a bug in
        // Opera <= 7.54u2 where `0 == -0`, but `String(-0) !== "0"`.
        return (leadingZeroes + (value || 0)).slice(-width);
      };

      // Internal: Double-quotes a string `value`, replacing all ASCII control
      // characters (characters with code unit values between 0 and 31) with
      // their escaped equivalents. This is an implementation of the
      // `Quote(value)` operation defined in ES 5.1 section 15.12.3.
      var unicodePrefix = "\\u00";
      var quote = function (value) {
        var result = '"', index = 0, length = value.length, isLarge = length > 10 && charIndexBuggy, symbols;
        if (isLarge) {
          symbols = value.split("");
        }
        for (; index < length; index++) {
          var charCode = value.charCodeAt(index);
          // If the character is a control character, append its Unicode or
          // shorthand escape sequence; otherwise, append the character as-is.
          switch (charCode) {
            case 8: case 9: case 10: case 12: case 13: case 34: case 92:
              result += Escapes[charCode];
              break;
            default:
              if (charCode < 32) {
                result += unicodePrefix + toPaddedString(2, charCode.toString(16));
                break;
              }
              result += isLarge ? symbols[index] : charIndexBuggy ? value.charAt(index) : value[index];
          }
        }
        return result + '"';
      };

      // Internal: Recursively serializes an object. Implements the
      // `Str(key, holder)`, `JO(value)`, and `JA(value)` operations.
      var serialize = function (property, object, callback, properties, whitespace, indentation, stack) {
        var value, className, year, month, date, time, hours, minutes, seconds, milliseconds, results, element, index, length, prefix, result;
        try {
          // Necessary for host object support.
          value = object[property];
        } catch (exception) {}
        if (typeof value == "object" && value) {
          className = getClass.call(value);
          if (className == dateClass && !isProperty.call(value, "toJSON")) {
            if (value > -1 / 0 && value < 1 / 0) {
              // Dates are serialized according to the `Date#toJSON` method
              // specified in ES 5.1 section 15.9.5.44. See section 15.9.1.15
              // for the ISO 8601 date time string format.
              if (getDay) {
                // Manually compute the year, month, date, hours, minutes,
                // seconds, and milliseconds if the `getUTC*` methods are
                // buggy. Adapted from @Yaffle's `date-shim` project.
                date = floor(value / 864e5);
                for (year = floor(date / 365.2425) + 1970 - 1; getDay(year + 1, 0) <= date; year++);
                for (month = floor((date - getDay(year, 0)) / 30.42); getDay(year, month + 1) <= date; month++);
                date = 1 + date - getDay(year, month);
                // The `time` value specifies the time within the day (see ES
                // 5.1 section 15.9.1.2). The formula `(A % B + B) % B` is used
                // to compute `A modulo B`, as the `%` operator does not
                // correspond to the `modulo` operation for negative numbers.
                time = (value % 864e5 + 864e5) % 864e5;
                // The hours, minutes, seconds, and milliseconds are obtained by
                // decomposing the time within the day. See section 15.9.1.10.
                hours = floor(time / 36e5) % 24;
                minutes = floor(time / 6e4) % 60;
                seconds = floor(time / 1e3) % 60;
                milliseconds = time % 1e3;
              } else {
                year = value.getUTCFullYear();
                month = value.getUTCMonth();
                date = value.getUTCDate();
                hours = value.getUTCHours();
                minutes = value.getUTCMinutes();
                seconds = value.getUTCSeconds();
                milliseconds = value.getUTCMilliseconds();
              }
              // Serialize extended years correctly.
              value = (year <= 0 || year >= 1e4 ? (year < 0 ? "-" : "+") + toPaddedString(6, year < 0 ? -year : year) : toPaddedString(4, year)) +
                "-" + toPaddedString(2, month + 1) + "-" + toPaddedString(2, date) +
                // Months, dates, hours, minutes, and seconds should have two
                // digits; milliseconds should have three.
                "T" + toPaddedString(2, hours) + ":" + toPaddedString(2, minutes) + ":" + toPaddedString(2, seconds) +
                // Milliseconds are optional in ES 5.0, but required in 5.1.
                "." + toPaddedString(3, milliseconds) + "Z";
            } else {
              value = null;
            }
          } else if (typeof value.toJSON == "function" && ((className != numberClass && className != stringClass && className != arrayClass) || isProperty.call(value, "toJSON"))) {
            // Prototype <= 1.6.1 adds non-standard `toJSON` methods to the
            // `Number`, `String`, `Date`, and `Array` prototypes. JSON 3
            // ignores all `toJSON` methods on these objects unless they are
            // defined directly on an instance.
            value = value.toJSON(property);
          }
        }
        if (callback) {
          // If a replacement function was provided, call it to obtain the value
          // for serialization.
          value = callback.call(object, property, value);
        }
        if (value === null) {
          return "null";
        }
        className = getClass.call(value);
        if (className == booleanClass) {
          // Booleans are represented literally.
          return "" + value;
        } else if (className == numberClass) {
          // JSON numbers must be finite. `Infinity` and `NaN` are serialized as
          // `"null"`.
          return value > -1 / 0 && value < 1 / 0 ? "" + value : "null";
        } else if (className == stringClass) {
          // Strings are double-quoted and escaped.
          return quote("" + value);
        }
        // Recursively serialize objects and arrays.
        if (typeof value == "object") {
          // Check for cyclic structures. This is a linear search; performance
          // is inversely proportional to the number of unique nested objects.
          for (length = stack.length; length--;) {
            if (stack[length] === value) {
              // Cyclic structures cannot be serialized by `JSON.stringify`.
              throw TypeError();
            }
          }
          // Add the object to the stack of traversed objects.
          stack.push(value);
          results = [];
          // Save the current indentation level and indent one additional level.
          prefix = indentation;
          indentation += whitespace;
          if (className == arrayClass) {
            // Recursively serialize array elements.
            for (index = 0, length = value.length; index < length; index++) {
              element = serialize(index, value, callback, properties, whitespace, indentation, stack);
              results.push(element === undef ? "null" : element);
            }
            result = results.length ? (whitespace ? "[\n" + indentation + results.join(",\n" + indentation) + "\n" + prefix + "]" : ("[" + results.join(",") + "]")) : "[]";
          } else {
            // Recursively serialize object members. Members are selected from
            // either a user-specified list of property names, or the object
            // itself.
            forEach(properties || value, function (property) {
              var element = serialize(property, value, callback, properties, whitespace, indentation, stack);
              if (element !== undef) {
                // According to ES 5.1 section 15.12.3: "If `gap` {whitespace}
                // is not the empty string, let `member` {quote(property) + ":"}
                // be the concatenation of `member` and the `space` character."
                // The "`space` character" refers to the literal space
                // character, not the `space` {width} argument provided to
                // `JSON.stringify`.
                results.push(quote(property) + ":" + (whitespace ? " " : "") + element);
              }
            });
            result = results.length ? (whitespace ? "{\n" + indentation + results.join(",\n" + indentation) + "\n" + prefix + "}" : ("{" + results.join(",") + "}")) : "{}";
          }
          // Remove the object from the traversed object stack.
          stack.pop();
          return result;
        }
      };

      // Public: `JSON.stringify`. See ES 5.1 section 15.12.3.
      JSON3.stringify = function (source, filter, width) {
        var whitespace, callback, properties, className;
        if (typeof filter == "function" || typeof filter == "object" && filter) {
          if ((className = getClass.call(filter)) == functionClass) {
            callback = filter;
          } else if (className == arrayClass) {
            // Convert the property names array into a makeshift set.
            properties = {};
            for (var index = 0, length = filter.length, value; index < length; value = filter[index++], ((className = getClass.call(value)), className == stringClass || className == numberClass) && (properties[value] = 1));
          }
        }
        if (width) {
          if ((className = getClass.call(width)) == numberClass) {
            // Convert the `width` to an integer and create a string containing
            // `width` number of space characters.
            if ((width -= width % 1) > 0) {
              for (whitespace = "", width > 10 && (width = 10); whitespace.length < width; whitespace += " ");
            }
          } else if (className == stringClass) {
            whitespace = width.length <= 10 ? width : width.slice(0, 10);
          }
        }
        // Opera <= 7.54u2 discards the values associated with empty string keys
        // (`""`) only if they are used directly within an object member list
        // (e.g., `!("" in { "": 1})`).
        return serialize("", (value = {}, value[""] = source, value), callback, properties, whitespace, "", []);
      };
    }

    // Public: Parses a JSON source string.
    if (!has("json-parse")) {
      var fromCharCode = String.fromCharCode;

      // Internal: A map of escaped control characters and their unescaped
      // equivalents.
      var Unescapes = {
        92: "\\",
        34: '"',
        47: "/",
        98: "\b",
        116: "\t",
        110: "\n",
        102: "\f",
        114: "\r"
      };

      // Internal: Stores the parser state.
      var Index, Source;

      // Internal: Resets the parser state and throws a `SyntaxError`.
      var abort = function() {
        Index = Source = null;
        throw SyntaxError();
      };

      // Internal: Returns the next token, or `"$"` if the parser has reached
      // the end of the source string. A token may be a string, number, `null`
      // literal, or Boolean literal.
      var lex = function () {
        var source = Source, length = source.length, value, begin, position, isSigned, charCode;
        while (Index < length) {
          charCode = source.charCodeAt(Index);
          switch (charCode) {
            case 9: case 10: case 13: case 32:
              // Skip whitespace tokens, including tabs, carriage returns, line
              // feeds, and space characters.
              Index++;
              break;
            case 123: case 125: case 91: case 93: case 58: case 44:
              // Parse a punctuator token (`{`, `}`, `[`, `]`, `:`, or `,`) at
              // the current position.
              value = charIndexBuggy ? source.charAt(Index) : source[Index];
              Index++;
              return value;
            case 34:
              // `"` delimits a JSON string; advance to the next character and
              // begin parsing the string. String tokens are prefixed with the
              // sentinel `@` character to distinguish them from punctuators and
              // end-of-string tokens.
              for (value = "@", Index++; Index < length;) {
                charCode = source.charCodeAt(Index);
                if (charCode < 32) {
                  // Unescaped ASCII control characters (those with a code unit
                  // less than the space character) are not permitted.
                  abort();
                } else if (charCode == 92) {
                  // A reverse solidus (`\`) marks the beginning of an escaped
                  // control character (including `"`, `\`, and `/`) or Unicode
                  // escape sequence.
                  charCode = source.charCodeAt(++Index);
                  switch (charCode) {
                    case 92: case 34: case 47: case 98: case 116: case 110: case 102: case 114:
                      // Revive escaped control characters.
                      value += Unescapes[charCode];
                      Index++;
                      break;
                    case 117:
                      // `\u` marks the beginning of a Unicode escape sequence.
                      // Advance to the first character and validate the
                      // four-digit code point.
                      begin = ++Index;
                      for (position = Index + 4; Index < position; Index++) {
                        charCode = source.charCodeAt(Index);
                        // A valid sequence comprises four hexdigits (case-
                        // insensitive) that form a single hexadecimal value.
                        if (!(charCode >= 48 && charCode <= 57 || charCode >= 97 && charCode <= 102 || charCode >= 65 && charCode <= 70)) {
                          // Invalid Unicode escape sequence.
                          abort();
                        }
                      }
                      // Revive the escaped character.
                      value += fromCharCode("0x" + source.slice(begin, Index));
                      break;
                    default:
                      // Invalid escape sequence.
                      abort();
                  }
                } else {
                  if (charCode == 34) {
                    // An unescaped double-quote character marks the end of the
                    // string.
                    break;
                  }
                  charCode = source.charCodeAt(Index);
                  begin = Index;
                  // Optimize for the common case where a string is valid.
                  while (charCode >= 32 && charCode != 92 && charCode != 34) {
                    charCode = source.charCodeAt(++Index);
                  }
                  // Append the string as-is.
                  value += source.slice(begin, Index);
                }
              }
              if (source.charCodeAt(Index) == 34) {
                // Advance to the next character and return the revived string.
                Index++;
                return value;
              }
              // Unterminated string.
              abort();
            default:
              // Parse numbers and literals.
              begin = Index;
              // Advance past the negative sign, if one is specified.
              if (charCode == 45) {
                isSigned = true;
                charCode = source.charCodeAt(++Index);
              }
              // Parse an integer or floating-point value.
              if (charCode >= 48 && charCode <= 57) {
                // Leading zeroes are interpreted as octal literals.
                if (charCode == 48 && ((charCode = source.charCodeAt(Index + 1)), charCode >= 48 && charCode <= 57)) {
                  // Illegal octal literal.
                  abort();
                }
                isSigned = false;
                // Parse the integer component.
                for (; Index < length && ((charCode = source.charCodeAt(Index)), charCode >= 48 && charCode <= 57); Index++);
                // Floats cannot contain a leading decimal point; however, this
                // case is already accounted for by the parser.
                if (source.charCodeAt(Index) == 46) {
                  position = ++Index;
                  // Parse the decimal component.
                  for (; position < length && ((charCode = source.charCodeAt(position)), charCode >= 48 && charCode <= 57); position++);
                  if (position == Index) {
                    // Illegal trailing decimal.
                    abort();
                  }
                  Index = position;
                }
                // Parse exponents. The `e` denoting the exponent is
                // case-insensitive.
                charCode = source.charCodeAt(Index);
                if (charCode == 101 || charCode == 69) {
                  charCode = source.charCodeAt(++Index);
                  // Skip past the sign following the exponent, if one is
                  // specified.
                  if (charCode == 43 || charCode == 45) {
                    Index++;
                  }
                  // Parse the exponential component.
                  for (position = Index; position < length && ((charCode = source.charCodeAt(position)), charCode >= 48 && charCode <= 57); position++);
                  if (position == Index) {
                    // Illegal empty exponent.
                    abort();
                  }
                  Index = position;
                }
                // Coerce the parsed value to a JavaScript number.
                return +source.slice(begin, Index);
              }
              // A negative sign may only precede numbers.
              if (isSigned) {
                abort();
              }
              // `true`, `false`, and `null` literals.
              if (source.slice(Index, Index + 4) == "true") {
                Index += 4;
                return true;
              } else if (source.slice(Index, Index + 5) == "false") {
                Index += 5;
                return false;
              } else if (source.slice(Index, Index + 4) == "null") {
                Index += 4;
                return null;
              }
              // Unrecognized token.
              abort();
          }
        }
        // Return the sentinel `$` character if the parser has reached the end
        // of the source string.
        return "$";
      };

      // Internal: Parses a JSON `value` token.
      var get = function (value) {
        var results, hasMembers;
        if (value == "$") {
          // Unexpected end of input.
          abort();
        }
        if (typeof value == "string") {
          if ((charIndexBuggy ? value.charAt(0) : value[0]) == "@") {
            // Remove the sentinel `@` character.
            return value.slice(1);
          }
          // Parse object and array literals.
          if (value == "[") {
            // Parses a JSON array, returning a new JavaScript array.
            results = [];
            for (;; hasMembers || (hasMembers = true)) {
              value = lex();
              // A closing square bracket marks the end of the array literal.
              if (value == "]") {
                break;
              }
              // If the array literal contains elements, the current token
              // should be a comma separating the previous element from the
              // next.
              if (hasMembers) {
                if (value == ",") {
                  value = lex();
                  if (value == "]") {
                    // Unexpected trailing `,` in array literal.
                    abort();
                  }
                } else {
                  // A `,` must separate each array element.
                  abort();
                }
              }
              // Elisions and leading commas are not permitted.
              if (value == ",") {
                abort();
              }
              results.push(get(value));
            }
            return results;
          } else if (value == "{") {
            // Parses a JSON object, returning a new JavaScript object.
            results = {};
            for (;; hasMembers || (hasMembers = true)) {
              value = lex();
              // A closing curly brace marks the end of the object literal.
              if (value == "}") {
                break;
              }
              // If the object literal contains members, the current token
              // should be a comma separator.
              if (hasMembers) {
                if (value == ",") {
                  value = lex();
                  if (value == "}") {
                    // Unexpected trailing `,` in object literal.
                    abort();
                  }
                } else {
                  // A `,` must separate each object member.
                  abort();
                }
              }
              // Leading commas are not permitted, object property names must be
              // double-quoted strings, and a `:` must separate each property
              // name and value.
              if (value == "," || typeof value != "string" || (charIndexBuggy ? value.charAt(0) : value[0]) != "@" || lex() != ":") {
                abort();
              }
              results[value.slice(1)] = get(lex());
            }
            return results;
          }
          // Unexpected token encountered.
          abort();
        }
        return value;
      };

      // Internal: Updates a traversed object member.
      var update = function(source, property, callback) {
        var element = walk(source, property, callback);
        if (element === undef) {
          delete source[property];
        } else {
          source[property] = element;
        }
      };

      // Internal: Recursively traverses a parsed JSON object, invoking the
      // `callback` function for each value. This is an implementation of the
      // `Walk(holder, name)` operation defined in ES 5.1 section 15.12.2.
      var walk = function (source, property, callback) {
        var value = source[property], length;
        if (typeof value == "object" && value) {
          // `forEach` can't be used to traverse an array in Opera <= 8.54
          // because its `Object#hasOwnProperty` implementation returns `false`
          // for array indices (e.g., `![1, 2, 3].hasOwnProperty("0")`).
          if (getClass.call(value) == arrayClass) {
            for (length = value.length; length--;) {
              update(value, length, callback);
            }
          } else {
            forEach(value, function (property) {
              update(value, property, callback);
            });
          }
        }
        return callback.call(source, property, value);
      };

      // Public: `JSON.parse`. See ES 5.1 section 15.12.2.
      JSON3.parse = function (source, callback) {
        var result, value;
        Index = 0;
        Source = "" + source;
        result = get(lex());
        // If a JSON string contains multiple tokens, it is invalid.
        if (lex() != "$") {
          abort();
        }
        // Reset the parser state.
        Index = Source = null;
        return callback && getClass.call(callback) == functionClass ? walk((value = {}, value[""] = result, value), "", callback) : result;
      };
    }
  }

  // Export for asynchronous module loaders.
  if (isLoader) {
    define(function () {
      return JSON3;
    });
  }
}(this));

},{}],6:[function(require,module,exports){
var SDK;

SDK = require('./widgetic');

window.Widgetic || (window.Widgetic = new SDK());

module.exports = window.Widgetic;

window.Blogvio = window.Widgetic;


},{"./widgetic":"tzAnED"}],"aP+Ks/":[function(require,module,exports){
var Composition, api, auth, comps, config, guid, messageType, method, methods, queue, _fn,
  __slice = [].slice;

config = require('config');

guid = require('utils/guid');

queue = require("./../../../../bower/queue-async/queue.js");

api = require('../../api');

auth = require('../../auth');

comps = {};

Composition = function(holder, opt1, opt2) {
  var client_id, composition, has_token, options, query, token, url,
    _this = this;
  if (opt2 == null) {
    opt2 = {};
  }
  if (typeof opt1 === 'string') {
    composition = opt1;
  }
  options = composition ? opt2 : opt1;
  if (composition == null) {
    composition = options.composition;
  }
  Widgetic.debug.timestamp('Widgetic.UI.Composition:constructor');
  this._queue = queue(1);
  this._queue.defer(function(next) {
    return _this._startQueue = next;
  });
  if (composition) {
    url = config.composition.replace('{id}', composition);
  } else {
    url = config.widget.replace('{id}', options.widget_id);
    if (options.id != null) {
      url += "#comp=" + options.id;
    }
    if (options.skin) {
      this.setSkin(options.skin);
    }
    if (options.content) {
      this.setContent(options.content);
    }
  }
  query = [];
  client_id = auth.getClientId();
  has_token = api.getStatus().status === 'connected';
  if ((options.widget_id != null) && !(client_id || has_token)) {
    throw new Error('Widgetic should be initialized before using the UI.Composition!');
  }
  if (token = options.token || api.accessToken()) {
    query.push('access_token=' + token);
  }
  if (client_id) {
    query.push('client_id=' + client_id);
  }
  if (options.wait_editor_init) {
    query.push('wait');
  }
  if (options.branding) {
    query.push('branding');
  }
  if (options.brand_pos) {
    query.push('bp=' + options.brand_pos);
  }
  if (query.length) {
    url = url.replace(/(\?)|((.)(\#)|($))/, "?" + (query.length ? query.join('&') : void 0) + "&$2");
  }
  this.id = guid();
  comps[this.id] = this;
  this._iframe = document.createElement('iframe');
  this._iframe.setAttribute('class', 'widgetic-composition');
  this._iframe.setAttribute('name', this.id);
  holder.appendChild(this._iframe);
  this._iframe.setAttribute('src', url);
  return this;
};

Composition.prototype.close = function() {
  comps[this.id] = null;
  this._iframe.parentNode.removeChild(this._iframe);
  this.off();
  return this;
};

Composition.prototype.queue = function(callback) {
  var _this = this;
  return this._queue.defer(function(next) {
    callback();
    return next();
  });
};

Composition.prototype._ready = function() {
  Widgetic.debug.timestamp('Widgetic.UI.Composition:_ready');
  return this._startQueue();
};

Composition.prototype._sendMessage = function(message) {
  var _this = this;
  this._queue.defer(function(next) {
    _this._iframe.contentWindow.postMessage(JSON.stringify(message), '*');
    return next();
  });
  return this;
};

Composition.prototype.on = function(ev, callback) {
  var calls, evs, name, _i, _len;
  evs = ev.split(' ');
  calls = this.hasOwnProperty('_callbacks') && this._callbacks || (this._callbacks = {});
  for (_i = 0, _len = evs.length; _i < _len; _i++) {
    name = evs[_i];
    calls[name] || (calls[name] = []);
    calls[name].push(callback);
  }
  return this;
};

Composition.prototype.off = function(ev, callback) {
  var cb, evs, i, list, name, _i, _j, _len, _len1, _ref;
  if (arguments.length === 0) {
    this._callbacks = {};
    return this;
  }
  if (!ev) {
    return this;
  }
  evs = ev.split(' ');
  for (_i = 0, _len = evs.length; _i < _len; _i++) {
    name = evs[_i];
    list = (_ref = this._callbacks) != null ? _ref[name] : void 0;
    if (!list) {
      continue;
    }
    if (!callback) {
      delete this._callbacks[name];
      continue;
    }
    for (i = _j = 0, _len1 = list.length; _j < _len1; i = ++_j) {
      cb = list[i];
      if (!(cb === callback)) {
        continue;
      }
      list = list.slice();
      list.splice(i, 1);
      this._callbacks[name] = list;
      break;
    }
  }
  return this;
};

Composition.prototype._trigger = function() {
  var args, callback, ev, list, _i, _len, _ref;
  args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  ev = args.shift();
  list = this.hasOwnProperty('_callbacks') && ((_ref = this._callbacks) != null ? _ref[ev] : void 0);
  if (!list) {
    return;
  }
  for (_i = 0, _len = list.length; _i < _len; _i++) {
    callback = list[_i];
    if (callback.apply(this, args) === false) {
      break;
    }
  }
  return true;
};

methods = {
  'clearContent': 'cx',
  'setContent': 'sc',
  'addContent': 'ac',
  'changeContent': 'cc',
  'removeContent': 'rc',
  'setSkin': 'ss',
  'changeSkin': 'cs',
  'removeSkin': 'rs',
  'saveSkin': 'sS',
  'save': 's',
  'saveDraft': 'sd',
  'setName': 'sn'
};

_fn = function(method, messageType) {
  return Composition.prototype[method] = function(data) {
    return this._sendMessage({
      t: messageType,
      d: data
    });
  };
};
for (method in methods) {
  messageType = methods[method];
  _fn(method, messageType);
}

Composition.connect = function(id) {
  return comps[id.d]._ready();
};

Composition.event = function(data) {
  return comps[data.id]._trigger(data.e, data.d);
};

module.exports = Composition;


},{"../../api":"pK1+ma","../../auth":"9joUsL","./../../../../bower/queue-async/queue.js":3,"config":"ZaiTg0","utils/guid":"EadS8b"}],"UI/composition/index":[function(require,module,exports){
module.exports=require('aP+Ks/');
},{}],"sk8aR+":[function(require,module,exports){
var Editor, api, config, editors, guid, pubsub, queue,
  __slice = [].slice;

config = require('config');

queue = require("./../../../../bower/queue-async/queue.js");

pubsub = require("./../../../../bower/pubsub.js/src/pubsub.js");

guid = require('utils/guid');

api = require('../../api');

editors = {};

Editor = function(holder, composition, opts) {
  var url,
    _this = this;
  this.composition = composition;
  Widgetic.debug.timestamp('Widgetic.UI.Editor:constructor');
  this._queue = queue(1);
  this._queue.defer(function(next) {
    return _this._startQueue = next;
  });
  pubsub.subscribe('api/token/update', this._updateToken.bind(this));
  this._updateToken();
  if (opts) {
    this.setEditorOptions(opts);
  }
  this.composition.queue(this._compReady.bind(this));
  editors[this.composition.id] = this;
  url = config.editor + '#' + this.composition.id;
  if (opts != null ? opts.asPopup : void 0) {
    if (this.frame = holder) {
      this.frame.location.href = url;
    } else {
      this.frame = window.open(url, guid(), "height=" + (opts.h || 565) + ",width=" + (opts.w || 490));
    }
  } else {
    this._iframe = document.createElement('iframe');
    this._iframe.setAttribute('class', 'widgetic-editor');
    this._iframe.setAttribute('name', guid());
    holder.appendChild(this._iframe);
    this._iframe.setAttribute('src', url);
    this.frame = this._iframe.contentWindow;
  }
  return this;
};

Editor.prototype.close = function() {
  editors[this.composition.id] = null;
  if (this._iframe) {
    this._iframe.parentNode.removeChild(this._iframe);
  } else {
    this.frame.close();
  }
  return this;
};

Editor.prototype.goTo = function(step) {
  this._sendMessage({
    t: 'step',
    d: step
  });
  return this;
};

Editor.prototype.setEditorOptions = function(options) {
  this.options = options != null ? options : this.options;
  this._sendMessage({
    t: 'opts',
    d: this.options
  });
  return this;
};

Editor.prototype.save = function() {
  this.goTo('done');
  return this;
};

Editor.prototype.on = function(ev, callback) {
  var calls, evs, name, _i, _len;
  evs = ev.split(' ');
  calls = this.hasOwnProperty('_callbacks') && this._callbacks || (this._callbacks = {});
  for (_i = 0, _len = evs.length; _i < _len; _i++) {
    name = evs[_i];
    calls[name] || (calls[name] = []);
    calls[name].push(callback);
  }
  return this;
};

Editor.prototype.off = function(ev, callback) {
  var cb, evs, i, list, name, _i, _j, _len, _len1, _ref;
  if (arguments.length === 0) {
    this._callbacks = {};
    return this;
  }
  if (!ev) {
    return this;
  }
  evs = ev.split(' ');
  for (_i = 0, _len = evs.length; _i < _len; _i++) {
    name = evs[_i];
    list = (_ref = this._callbacks) != null ? _ref[name] : void 0;
    if (!list) {
      continue;
    }
    if (!callback) {
      delete this._callbacks[name];
      continue;
    }
    for (i = _j = 0, _len1 = list.length; _j < _len1; i = ++_j) {
      cb = list[i];
      if (!(cb === callback)) {
        continue;
      }
      list = list.slice();
      list.splice(i, 1);
      this._callbacks[name] = list;
      break;
    }
  }
  return this;
};

Editor.prototype._trigger = function() {
  var args, callback, ev, list, _i, _len, _ref;
  args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  ev = args.shift();
  list = this.hasOwnProperty('_callbacks') && ((_ref = this._callbacks) != null ? _ref[ev] : void 0);
  if (!list) {
    return;
  }
  for (_i = 0, _len = list.length; _i < _len; _i++) {
    callback = list[_i];
    if (callback.apply(this, args) === false) {
      break;
    }
  }
  return true;
};

Editor.prototype._sendMessage = function(message) {
  var _this = this;
  return this._queue.defer(function(next) {
    _this.frame.postMessage(JSON.stringify(message), '*');
    return next();
  });
};

Editor.prototype._ready = function() {
  this.ready = true;
  Widgetic.debug.timestamp('Widgetic.UI.Editor:_ready');
  return this._startQueue();
};

Editor.prototype._compReady = function() {
  this.compReady = true;
  Widgetic.debug.timestamp('Widgetic.UI.Editor:_compReady');
  return this._sendMessage({
    t: 'ready'
  });
};

Editor.prototype._updateToken = function() {
  Widgetic.debug.timestamp('Widgetic.UI.Editor:_updateToken');
  return this._sendMessage({
    t: 'token',
    d: api.accessToken()
  });
};

Editor.prototype._onConnect = function() {
  var _this = this;
  if (this.ready && this.compReady) {
    this._queue.defer(function(next) {
      _this.setEditorOptions();
      _this._compReady();
      return next();
    });
  }
  return this._ready();
};

Editor.connect = function(data) {
  return editors[data.id]._onConnect();
};

Editor.event = function(data) {
  return editors[data.id]._trigger(data.e, data.d);
};

module.exports = Editor;


},{"../../api":"pK1+ma","./../../../../bower/pubsub.js/src/pubsub.js":2,"./../../../../bower/queue-async/queue.js":3,"config":"ZaiTg0","utils/guid":"EadS8b"}],"UI/editor/index":[function(require,module,exports){
module.exports=require('sk8aR+');
},{}],"4bzqDg":[function(require,module,exports){
var Composition, Editor, composition, editor, parse, plugin, popup;

Composition = require('./composition');

Editor = require('./editor');

plugin = require('./plugin');

popup = require('./popup');

parse = require('./parse');

composition = function() {
  return (function(func, args, ctor) {
    ctor.prototype = func.prototype;
    var child = new ctor, result = func.apply(child, args);
    return Object(result) === result ? result : child;
  })(Composition, arguments, function(){});
};

editor = function() {
  return (function(func, args, ctor) {
    ctor.prototype = func.prototype;
    var child = new ctor, result = func.apply(child, args);
    return Object(result) === result ? result : child;
  })(Editor, arguments, function(){});
};

module.exports = {
  composition: composition,
  editor: editor,
  parse: parse,
  popup: popup,
  plugin: plugin
};


},{"./composition":"aP+Ks/","./editor":"sk8aR+","./parse":"RadvXf","./plugin":"vqfNgY","./popup":"7FyBBT"}],"UI/index":[function(require,module,exports){
module.exports=require('4bzqDg');
},{}],"UI/parse":[function(require,module,exports){
module.exports=require('RadvXf');
},{}],"RadvXf":[function(require,module,exports){
var defaultResizeStyle, embed, getHolder, parse, replaceParentWithChild, resizeHolderTemplate, stylesFactory, whenReady;

whenReady = require('../utils/ready');

defaultResizeStyle = 'allow-scale-down';

replaceParentWithChild = function(parent) {
  var child, frag, grandparent;
  child = parent.children[0];
  grandparent = parent.parentNode;
  parent.removeChild(child);
  frag = document.createDocumentFragment();
  frag.insertBefore(child, null);
  grandparent.insertBefore(frag, parent);
  grandparent.removeChild(parent);
  return child;
};

getHolder = function(wrapper) {
  return wrapper.children[0];
};

resizeHolderTemplate = function(id, styles) {
  return "<div class=\"wdgtc-wrap\" data-wdgtc-id=\"" + id + "\" style=\"width:100%;" + (styles.wrapStyle || '') + "\">		<div class=\"wdgtc-holder\" style=\"position:relative; padding: 0;" + (styles.holdStyle || '') + "\">		</div>	</div>";
};

stylesFactory = {
  'fixed': function(width, height) {
    var ratio;
    ratio = height * 100 / width;
    return {
      wrapStyle: "max-width: " + width + "px; min-width: " + width + "px;",
      holdStyle: "padding-top: " + ratio + "%;"
    };
  },
  'allow-scale-down': function(width, height) {
    var ratio;
    ratio = height * 100 / width;
    return {
      wrapStyle: "max-width: " + width + "px;",
      holdStyle: "padding-top: " + ratio + "%;"
    };
  },
  'fixed-height': function(width, height) {
    return {
      holdStyle: "height: " + height + "px; padding-top: 0;"
    };
  },
  'fill-width': function(width, height) {
    var ratio;
    ratio = height * 100 / width;
    return {
      holdStyle: "padding-top: " + ratio + "%;"
    };
  },
  'fill': function(width, height) {
    return {
      wrapStyle: "height: 100%",
      holdStyle: "height: 100%"
    };
  }
};

parse = function() {
  return whenReady(function() {
    var compositionEls, el, _i, _len;
    compositionEls = document.querySelectorAll('.widgetic-composition');
    for (_i = 0, _len = compositionEls.length; _i < _len; _i++) {
      el = compositionEls[_i];
      embed(el);
    }
  });
};

embed = function(el) {
  var composition, holder, options, styles,
    _this = this;
  options = {
    composition: el.getAttribute('data-id'),
    width: el.getAttribute('data-width') || 300,
    height: el.getAttribute('data-height') || 300,
    resize: el.getAttribute('data-resize') || defaultResizeStyle,
    brand_pos: el.getAttribute('data-brand') || 'bottom-right',
    branding: el.hasAttribute('data-branding')
  };
  if (!options.composition) {
    return;
  }
  if (!stylesFactory[options.resize]) {
    options.resize = defaultResizeStyle;
  }
  styles = stylesFactory[options.resize](options.width, options.height);
  el.insertAdjacentHTML('afterbegin', resizeHolderTemplate(options.id, styles));
  el = replaceParentWithChild(el);
  holder = getHolder(el);
  composition = new Widgetic.UI.composition(holder, options.composition, options);
  composition._iframe.setAttribute('style', 'position:absolute;top:0;left:0;width:100%;height:100%;');
  composition._iframe.style.visibility = 'hidden';
  return composition._iframe.onload = function() {
    return composition._iframe.style.visibility = 'visible';
  };
};

module.exports = parse;


},{"../utils/ready":"IiXnYl"}],"vqfNgY":[function(require,module,exports){
var Plugin, api, config, guid, pubsub, queue,
  __slice = [].slice;

config = require('config');

queue = require("./../../../../bower/queue-async/queue.js");

pubsub = require("./../../../../bower/pubsub.js/src/pubsub.js");

guid = require('utils/guid');

api = require('../../api');

Plugin = (function() {
  Plugin.instances = {};

  Plugin.connect = function(data) {
    var instance;
    instance = Plugin.instances[data.id];
    instance._updateToken();
    instance._ready();
    return instance._sendMessage({
      t: 'ready'
    });
  };

  Plugin.event = function(data) {
    return Plugin.instances[data.id]._trigger(data.e, data.d);
  };

  Plugin.create = function(opts) {
    var instance;
    if (opts == null) {
      opts = {};
    }
    instance = new this(opts);
    return this.instances[instance.id] = instance;
  };

  function Plugin(opts) {
    var url, _ref,
      _this = this;
    this.id = guid();
    this.name = opts.name || this.id;
    Widgetic.debug.timestamp('Widgetic.UI.Plugin:constructor');
    this._queue = queue(1);
    this._queue.defer(function(next) {
      return _this._startQueue = next;
    });
    pubsub.subscribe('api/token/update', this._updateToken.bind(this));
    this._updateToken();
    if (opts) {
      this.setOptions(opts);
    }
    url = config.plugin;
    if (this.frame = ((_ref = opts.holder) != null ? _ref.document : void 0) || opts.holder) {
      this._iframe = document.createElement('iframe');
      this._iframe.setAttribute('class', 'wdtc-plugin');
      this._iframe.setAttribute('name', this.name);
      this.frame.appendChild(this._iframe);
      this._iframe.setAttribute('src', url);
      this.frame = this._iframe.contentWindow;
    } else {
      this.frame = window.open(url, this.name, "height=" + (opts.h || 760) + ",width=" + (opts.w || 1270));
    }
  }

  Plugin.prototype.close = function() {
    this.constructor.instances[this.id] = null;
    delete this.constructor.instances[this.id];
    if (this._iframe) {
      this._iframe.parentNode.removeChild(this._iframe);
    } else {
      this.frame.close();
    }
    return this;
  };

  Plugin.prototype.setOptions = function(options) {
    this.options = options != null ? options : this.options;
    this._sendMessage({
      t: 'opts',
      d: this.options
    });
    return this;
  };

  Plugin.prototype.on = function(ev, callback) {
    var calls, evs, name, _i, _len;
    evs = ev.split(' ');
    calls = this.hasOwnProperty('_callbacks') && this._callbacks || (this._callbacks = {});
    for (_i = 0, _len = evs.length; _i < _len; _i++) {
      name = evs[_i];
      calls[name] || (calls[name] = []);
      calls[name].push(callback);
    }
    return this;
  };

  Plugin.prototype.off = function(ev, callback) {
    var cb, evs, i, list, name, _i, _j, _len, _len1, _ref;
    if (arguments.length === 0) {
      this._callbacks = {};
      return this;
    }
    if (!ev) {
      return this;
    }
    evs = ev.split(' ');
    for (_i = 0, _len = evs.length; _i < _len; _i++) {
      name = evs[_i];
      list = (_ref = this._callbacks) != null ? _ref[name] : void 0;
      if (!list) {
        continue;
      }
      if (!callback) {
        delete this._callbacks[name];
        continue;
      }
      for (i = _j = 0, _len1 = list.length; _j < _len1; i = ++_j) {
        cb = list[i];
        if (!(cb === callback)) {
          continue;
        }
        list = list.slice();
        list.splice(i, 1);
        this._callbacks[name] = list;
        break;
      }
    }
    return this;
  };

  Plugin.prototype._trigger = function() {
    var args, callback, ev, list, _i, _len, _ref;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    ev = args.shift();
    list = this.hasOwnProperty('_callbacks') && ((_ref = this._callbacks) != null ? _ref[ev] : void 0);
    if (!list) {
      return;
    }
    for (_i = 0, _len = list.length; _i < _len; _i++) {
      callback = list[_i];
      if (callback.apply(this, args) === false) {
        break;
      }
    }
    return true;
  };

  Plugin.prototype._sendMessage = function(message) {
    var _this = this;
    return this._queue.defer(function(next) {
      _this.frame.postMessage(JSON.stringify(message), '*');
      return next();
    });
  };

  Plugin.prototype._ready = function() {
    Widgetic.debug.timestamp('Widgetic.UI.Plugin:_ready');
    return this._startQueue();
  };

  Plugin.prototype._updateToken = function() {
    Widgetic.debug.timestamp('Widgetic.UI.Plugin:_updateToken');
    return this._sendMessage({
      t: 'token',
      d: api.accessToken()
    });
  };

  return Plugin;

}).call(this);

module.exports = Plugin;


},{"../../api":"pK1+ma","./../../../../bower/pubsub.js/src/pubsub.js":2,"./../../../../bower/queue-async/queue.js":3,"config":"ZaiTg0","utils/guid":"EadS8b"}],"UI/plugin/index":[function(require,module,exports){
module.exports=require('vqfNgY');
},{}],"7FyBBT":[function(require,module,exports){
var Popup, ackMessage, aye, config, debounce, defs, event, extend, getCssValue, getOffset, getTextFromStyleElement, guid, json, loadSheet, newMessage, replyMessage, send, ucfirst,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

aye = require("./../../../../bower/aye/ayepromise.js");

guid = require('utils/guid');

json = require('json3');

event = require('utils/event');

config = require('config');

extend = function(out) {
  var arg, key, _i, _len;
  if (out == null) {
    out = {};
  }
  for (_i = 0, _len = arguments.length; _i < _len; _i++) {
    arg = arguments[_i];
    if (!arg) {
      continue;
    }
    for (key in arg) {
      if (arg.hasOwnProperty(key)) {
        out[key] = arg[key];
      }
    }
  }
  return out;
};

debounce = function(fn, t) {
  var _delay;
  if (t == null) {
    t = 10;
  }
  _delay = null;
  return function() {
    clearTimeout(_delay);
    return _delay = setTimeout(fn, t);
  };
};

getOffset = function(el) {
  var rect;
  rect = el.getBoundingClientRect();
  return {
    top: rect.top + document.body.scrollTop,
    left: rect.left + document.body.scrollLeft
  };
};

loadSheet = function(url, el, callback) {
  var link;
  link = this.document.createElement('link');
  link.setAttribute('rel', 'stylesheet');
  link.setAttribute('type', 'text/css');
  link.setAttribute('charset', 'utf-8');
  link.setAttribute('href', url);
  if (callback) {
    event.on(link, 'load', callback);
  }
  return el.appendChild(link);
};

defs = {};

newMessage = function(data) {
  var deffered, defid, message, promise;
  defid = guid();
  promise = (defs[defid] = deffered = aye.defer()).promise;
  message = {
    id: defid,
    t: 'p',
    d: data
  };
  return {
    promise: promise,
    message: message
  };
};

ackMessage = function(message, data) {
  return defs[message.id].resolve(data);
};

send = function(message, target) {
  if (target == null) {
    target = window.parent;
  }
  if (typeof target === 'string') {
    target = window.frames[target];
  }
  return target.postMessage(JSON.stringify(message), '*');
};

replyMessage = function(message, event, response) {
  message.d.original = message.d.event;
  message.d.event = 'done';
  message.d.response = response;
  return send(message, event.source);
};

ucfirst = function(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
};

getCssValue = function(el, property) {
  var value;
  if (!el) {
    return void 0;
  }
  value = window.getComputedStyle(el).getPropertyValue(property);
  if (!value) {
    return void 0;
  }
  return value;
};

getTextFromStyleElement = function(el) {
  try {
    return el.innerHTML;
  } catch (_error) {
    return el.styleSheet.cssText;
  }
};

Popup = (function() {
  Popup.styles = {
    popup: '\
			body {\
				display:inline-block;\
				margin:0;\
				width:auto !important;\
				height:auto !important;\
				overflow:hidden;\
				background:transparent !important\
			}\
		',
    overlay: '\
			html, body {\
				width:100%;\
				height:100%;\
			}\
			body {\
				display:block;\
				margin:0;\
				overflow:hidden;\
			}\
		'
  };

  Popup.popups = {};

  Popup.callbacks = {};

  Popup.iframes = {};

  Popup["new"] = function(options) {
    var name;
    if (options == null) {
      options = {};
    }
    name = options.name || guid();
    options.name = name;
    this.popups[name] = new Popup(options);
    return this.popups[name].init();
  };

  Popup.receiver = function(message, event) {
    var method;
    method = message.d.event;
    method = 'on' + ucfirst(method);
    return typeof Popup[method] === "function" ? Popup[method](message, event) : void 0;
  };

  Popup.onCreate = function(message, ev) {
    var iframe, name,
      _this = this;
    name = message.d.name;
    iframe = document.createElement('iframe');
    iframe.setAttribute('class', 'wdgtc-popup');
    iframe.setAttribute('name', name);
    iframe.isOverlay = message.d.type === 'overlay';
    iframe.setAttribute('style', 'border: 0; width: 0; height: 0; position: absolute; top: 0; left: -10000px; z-index: 2147483646;');
    if (iframe.isOverlay) {
      iframe.style.zIndex = 2147483647;
    }
    iframe.isVisible = false;
    iframe._parent = ev.source;
    document.querySelectorAll('body')[0].appendChild(iframe);
    iframe.setAttribute('src', config.popup + '&name=' + encodeURIComponent(name) + '&event=ready');
    this.iframes[name] = iframe;
    iframe.doPosition = debounce(this.doPosition.bind(this, iframe, null), 0);
    event.on(window, 'resize', iframe.doPosition);
    event.on(window, 'scroll', iframe.doPosition);
    return this.callbacks[name] = function() {
      delete _this.callbacks[name];
      return replyMessage(message, ev);
    };
  };

  Popup.onReady = function(message) {
    var _base, _name;
    return typeof (_base = this.callbacks)[_name = message.d.name] === "function" ? _base[_name]() : void 0;
  };

  Popup.onDone = function(message, event) {
    var method;
    method = message.d.original;
    method = 'on' + ucfirst(method) + 'Done';
    if (this[method]) {
      return this[method](message, event);
    }
    return ackMessage(message, message.d.response);
  };

  Popup.onCreateDone = function(message, event) {
    return ackMessage(message, event.source.frames[message.d.name]);
  };

  Popup.onManage = function(message, event) {
    var iframe, method, name, response;
    name = message.d.name;
    iframe = this.iframes[name];
    method = 'do' + ucfirst(message.d["do"]);
    response = typeof this[method] === "function" ? this[method](iframe, message.d) : void 0;
    return replyMessage(message, event, response);
  };

  Popup.doResize = function(iframe, options) {
    if (iframe.isOverlay) {
      return options.dimensions;
    }
    iframe.style.width = options.dimensions.width + 'px';
    iframe.style.height = options.dimensions.height + 'px';
    if (options.dimensions.shadow) {
      iframe.style.boxShadow = options.dimensions.shadow;
    }
    if (options.dimensions.borderRadius) {
      iframe.style.borderRadius = options.dimensions.borderRadius;
    }
    return options.dimensions;
  };

  Popup.doHide = function(iframe, options) {
    iframe.isVisible = false;
    iframe.style.display = 'none';
  };

  Popup.doShow = function(iframe, options) {
    iframe.isVisible = true;
    iframe.style.display = 'block';
    iframe.style.position = iframe.isOverlay ? 'fixed' : 'absolute';
  };

  Popup.doPosition = function(iframe, options) {
    var anchor, frame, left, offset, popup, top, _ref;
    if (!iframe.isVisible) {
      iframe.style.display = "none";
    }
    if (iframe.isOverlay) {
      iframe.style.position = 'fixed';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.style.top = 0;
      iframe.style.left = 0;
      iframe.style.bottom = 0;
      iframe.style.right = 0;
      return;
    }
    if (options) {
      iframe.positionOptions = options;
    } else {
      if (!iframe.positionOptions) {
        return;
      }
      options = iframe.positionOptions;
    }
    offset = options.offset;
    popup = options.dimensions;
    anchor = extend({}, options.anchor);
    frame = document.querySelector("iframe[name=\"" + anchor.parent + "\"]");
    if (frame) {
      _ref = getOffset(frame), top = _ref.top, left = _ref.left;
      anchor.top += top;
      anchor.left += left;
    }
    left = window.innerWidth + document.body.scrollLeft - (anchor.left + popup.width + offset.rightMargin + offset.leftOffset);
    left = anchor.left + offset.leftOffset + Math.min(0, left);
    left = Math.max(left, anchor.left + anchor.width - popup.width);
    top = window.innerHeight + document.body.scrollTop - (anchor.top + anchor.height + popup.height + offset.bottomMargin);
    top = top >= 0 ? anchor.top + anchor.height + offset.topOffset : anchor.top - popup.height - offset.bottomMargin;
    if (top < 0) {
      top = anchor.top + anchor.height + offset.topOffset;
    }
    iframe.style.top = top + 'px';
    iframe.style.left = left + 'px';
  };

  Popup.doRelease = function(iframe, options) {
    var name;
    iframe.parentNode.removeChild(iframe);
    event.off(window, 'resize', iframe.doPosition);
    event.off(window, 'scroll', iframe.doPosition);
    name = options.name;
    delete this.iframes[name];
  };

  Popup.hideAll = function() {
    var id, iframe, iframes;
    iframes = (function() {
      var _ref, _results;
      _ref = Popup.iframes;
      _results = [];
      for (id in _ref) {
        iframe = _ref[id];
        _results.push(iframe);
      }
      return _results;
    })();
    return iframes.filter(function(iframe) {
      return iframe.isVisible;
    }).map(function(iframe) {
      Popup.doHide(iframe);
      return send({
        t: 'p',
        d: {
          event: 'hide',
          name: iframe.name
        }
      }, iframe._parent);
    });
  };

  Popup.onHide = function(message, event) {
    var popup;
    popup = this.popups[message.d.name];
    return popup._hide();
  };

  Popup.prototype.type = 'popup';

  Popup.prototype.topOffset = 0;

  Popup.prototype.leftOffset = 0;

  Popup.prototype.rightMargin = 15;

  Popup.prototype.bottomMargin = 15;

  Popup.prototype.copyStyles = true;

  function Popup(options) {
    this._prepare = __bind(this._prepare, this);
    this.position = __bind(this.position, this);
    this._hide = __bind(this._hide, this);
    this.resize = __bind(this.resize, this);
    var key, value, _ref;
    this.options = options;
    _ref = this.options;
    for (key in _ref) {
      value = _ref[key];
      this[key] = value;
    }
    if (this.anchor == null) {
      this.anchor = document.body;
    }
    if (this.anchor.jquery) {
      this.anchor = this.anchor[0];
    }
    this.dimensions = {
      width: 0,
      height: 0
    };
    this.visible = false;
    this.styles = {};
  }

  Popup.prototype.init = function() {
    var promise;
    promise = this._sendEvent('create', {
      type: this.type
    });
    return promise.then(this._prepare);
  };

  Popup.prototype.append = function(el) {
    if (el.jquery) {
      el = el[0];
    }
    this.document.body.innerHTML = '';
    this.document.body.appendChild(el);
    this.styles = {};
    this._updateCachedStyles(el);
    return this.resize();
  };

  Popup.prototype.style = function(text, preserve) {
    var deferred;
    if (preserve == null) {
      preserve = false;
    }
    if (!this.styleElement) {
      this.styleElement = document.createElement('style');
      this.head.appendChild(this.styleElement);
    }
    if (this.preservedStyles == null) {
      this.preservedStyles = '';
    }
    try {
      this.styleElement.innerHTML = this.preservedStyles + text;
    } catch (_error) {
      this.styleElement.styleSheet.cssText = this.preservedStyles + text;
    }
    if (preserve) {
      this.preservedStyles += text;
    }
    deferred = aye.defer();
    deferred.resolve(this.preservedStyles + text);
    return deferred.promise;
  };

  Popup.prototype.resize = function() {
    this.dimensions = {
      width: this.document.body.offsetWidth,
      height: this.document.body.offsetHeight,
      shadow: this.styles['box-shadow'],
      borderRadius: this.styles['border-radius']
    };
    return this._sendEvent('manage', {
      "do": 'resize',
      dimensions: this.dimensions
    });
  };

  Popup.prototype.hide = function() {
    return this._sendEvent('manage', {
      "do": 'hide'
    }).then(this._hide);
  };

  Popup.prototype._hide = function() {
    return this.visible = false;
  };

  Popup.prototype.show = function() {
    var _this = this;
    return this.position().then(function() {
      return _this._sendEvent('manage', {
        "do": 'show'
      }).then(function() {
        return _this.visible = true;
      });
    });
  };

  Popup.prototype.position = function() {
    var anchor, offset;
    offset = {
      topOffset: this.topOffset,
      leftOffset: this.leftOffset,
      bottomMargin: this.bottomMargin,
      rightMargin: this.rightMargin
    };
    anchor = getOffset(this.anchor);
    anchor.parent = window.name;
    anchor.width = parseInt(this.anchor.offsetWidth, 10);
    anchor.height = parseInt(this.anchor.offsetHeight, 10);
    return this._sendEvent('manage', {
      "do": 'position',
      anchor: anchor,
      dimensions: this.dimensions,
      offset: offset
    });
  };

  Popup.prototype.release = function() {
    var deferred, promise,
      _this = this;
    deferred = aye.defer();
    promise = deferred.promise;
    this.document.location.reload();
    setTimeout(deferred.resolve, 1000);
    return promise.then(function() {
      return _this._sendEvent('manage', {
        "do": 'release'
      });
    });
  };

  Popup.prototype._sendEvent = function(event, extra) {
    var data, message, promise, _ref;
    data = {
      name: this.name,
      event: event
    };
    data = extend(data, extra);
    _ref = newMessage(data), promise = _ref.promise, message = _ref.message;
    send(message, this.targetWindow);
    return promise;
  };

  Popup.prototype._prepare = function(window) {
    var allSheetsLoaded, loadedSheets, onLoad, sheet, styles, _i, _len, _ref,
      _this = this;
    this.window = window;
    this.document = this.window.document;
    this.head = this.document.head;
    styles = '<style type="text/css">' + Popup.styles[this.type] + '</style>';
    this.head.insertAdjacentHTML('beforeend', styles);
    styles = document.querySelectorAll('[data-widget-style=true]');
    styles = Array.prototype.map.call(styles, getTextFromStyleElement);
    styles = styles.reduce((function(previous, current) {
      return previous += current;
    }), '');
    this.style(styles, true);
    if (!this.css) {
      return this;
    }
    allSheetsLoaded = aye.defer();
    loadedSheets = 0;
    onLoad = function() {
      if (++loadedSheets === _this.css.length) {
        return allSheetsLoaded.resolve();
      }
    };
    _ref = this.css;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      sheet = _ref[_i];
      loadSheet(sheet, this.head, onLoad);
    }
    setTimeout(allSheetsLoaded.reject.bind(null, new Error('Popup could not be created because CSS did not load')), 10000);
    return allSheetsLoaded.promise.then(function() {
      if (_this.document.body.children[0]) {
        _this._updateCachedStyles(_this.document.body.children[0]);
      }
      return _this.resize().then(function() {
        return _this;
      });
    });
  };

  Popup.prototype._updateCachedStyles = function(el) {
    if (!this.copyStyles) {
      return;
    }
    this._cacheStyle(el, 'box-shadow');
    return this._cacheStyle(el, 'border-radius');
  };

  Popup.prototype._cacheStyle = function(el, value) {
    return this.styles[value] = getCssValue(el, value);
  };

  return Popup;

}).call(this);

event.on(window.document, 'click', Popup.hideAll);

module.exports = Popup;


},{"./../../../../bower/aye/ayepromise.js":1,"config":"ZaiTg0","json3":5,"utils/event":"OZFmFt","utils/guid":"EadS8b"}],"UI/popup/index":[function(require,module,exports){
module.exports=require('7FyBBT');
},{}],"pK1+ma":[function(require,module,exports){
var api, aye, config, defs, guid, json, link, prepare_message, pubsub, queue, request, requestToken, tknDelay, tokenDef;

config = require('../config');

request = require('./request');

queue = require('../utils/queue');

guid = require('../utils/guid');

aye = require("./../../../bower/aye/ayepromise.js");

json = require('json3');

pubsub = require("./../../../bower/pubsub.js/src/pubsub.js");

defs = {};

link = {};

tokenDef = null;

tknDelay = null;

prepare_message = function(url, method, data, id) {
  var access_token, _ref;
  url = config.api + url;
  access_token = ((_ref = link.tokens) != null ? _ref.access_token : void 0) || false;
  if ((method || (method = 'GET')) instanceof Object) {
    data = method;
    method = 'GET';
  }
  if (method !== 'GET') {
    url = url + (access_token ? "?access_token=" + access_token : '');
  } else {
    data || (data = {});
    if (access_token) {
      data.access_token = access_token;
    }
  }
  return json.stringify({
    t: "a",
    id: id,
    a: {
      u: url,
      m: method,
      d: data
    }
  });
};

api = function(url, method, data) {
  var deffered, id, promise,
    _this = this;
  id = guid();
  promise = (defs[id] = deffered = aye.defer()).promise;
  queue.defer(function(next) {
    var advance, message;
    message = prepare_message.apply(_this, deffered.margs = [url, method, data, id]);
    promise.then(advance = (function() {
      return defs[id] = null || next();
    }), advance);
    return link.proxy(message);
  });
  return promise;
};

api.response = function(message) {
  var a, data, deffered, ok, _ref;
  deffered = defs[message.id];
  a = message.a;
  data = a.d;
  if (data !== "") {
    try {
      data = json.parse(data);
    } catch (_error) {
      deffered.reject("JSON Parse error!");
      return;
    }
  }
  if (a.t === 't') {
    return deffered.resolve(data);
  } else {
    if (link.tokens && data.error && ((_ref = data.error) === 'invalid_grant' || _ref === 'access_denied')) {
      ok = function() {
        tokenDef = null;
        return link.proxy(prepare_message.apply(this, deffered.margs));
      };
      return requestToken().then(ok, (function() {
        tokenDef = null;
        return deffered.reject('Unable to login again!');
      }));
    } else {
      return deffered.reject(data);
    }
  }
};

requestToken = function() {
  var auth, message, promise;
  if ((auth = require('../auth/index')).getClientId() != null) {
    return auth(false);
  }
  promise = (tokenDef = aye.defer()).promise;
  message = json.stringify({
    t: 'r',
    d: [false]
  });
  window.parent.postMessage(message, config.lo);
  tknDelay = setTimeout(tokenDef.reject, 3000);
  return promise;
};

api.setProxy = function(proxy) {
  return link.proxy = proxy;
};

api.setTokens = function(tokens) {
  link.tokens = tokens;
  return pubsub.publish('api/token/update');
};

api.getStatus = function() {
  var _ref;
  if ((_ref = link.tokens) != null ? _ref.access_token : void 0) {
    return {
      status: 'connected',
      accessToken: link.tokens.access_token,
      expiresIn: link.tokens.expires_in,
      scope: link.tokens.scope
    };
  } else {
    return {
      status: 'disconnected'
    };
  }
};

api.accessToken = function(token) {
  var _ref;
  if (token) {
    clearTimeout(tknDelay);
    if (tokenDef != null) {
      tokenDef.resolve(token);
    }
    api.setTokens({
      access_token: token,
      expires_in: void 0,
      scope: void 0
    });
  }
  return (_ref = link.tokens) != null ? _ref.access_token : void 0;
};

api.disconnect = function() {
  pubsub.publish('api/token/update');
  return link.tokens = null;
};

api.queue = queue;

api.request = request;

module.exports = api;


},{"../auth/index":"9joUsL","../config":"ZaiTg0","../utils/guid":"EadS8b","../utils/queue":"GkoH8v","./../../../bower/aye/ayepromise.js":1,"./../../../bower/pubsub.js/src/pubsub.js":2,"./request":"kgtKz9","json3":5}],"api/index":[function(require,module,exports){
module.exports=require('pK1+ma');
},{}],"kgtKz9":[function(require,module,exports){
var json, request, uxhr;

uxhr = require("./../../../bower/uxhr/uxhr.js");

json = require('json3');

request = function(params) {
  var a, complete, data, headers, message, method, settings, url;
  if (!(params.id && (a = params.a))) {
    return;
  }
  url = a.u;
  method = a.m;
  data = a.d;
  message = {
    id: params.id,
    t: 'e',
    a: {}
  };
  headers = {
    "Content-type": "application/json"
  };
  if ((method = method.toUpperCase()) === 'PUT' || method === "DELETE") {
    headers['X-HTTP-Method-Override'] = method;
    method = "POST";
  }
  complete = function(response, status) {
    message.a.t = status === 200 || status === 201 || status === 202 || status === 204 ? 't' : 'f';
    message.a.d = response;
    message = json.stringify(message);
    return window.parent.postMessage(message, '*');
  };
  settings = {
    method: method,
    headers: headers,
    complete: complete
  };
  return uxhr(url, data, settings);
};

module.exports = request;


},{"./../../../bower/uxhr/uxhr.js":4,"json3":5}],"api/request":[function(require,module,exports){
module.exports=require('kgtKz9');
},{}],"67urtb":[function(require,module,exports){
var aye, iframe, link, rwin;

aye = require("./../../../bower/aye/ayepromise.js");

rwin = window;

link = {};

iframe = function(url, deffered) {
  var clear, fail, parent, promise, timeout;
  promise = deffered.promise;
  iframe = document.createElement('iframe');
  parent = link.root.el;
  parent.appendChild(iframe);
  fail = function() {
    return deffered.reject('Timeout error');
  };
  clear = function() {
    parent.removeChild(iframe);
    return clearTimeout(timeout);
  };
  timeout = setTimeout(fail, 10000);
  promise.then(clear, clear);
  iframe.setAttribute('src', url);
  return promise;
};

iframe.setRoot = function(root) {
  return link.root = root;
};

module.exports = iframe;


},{"./../../../bower/aye/ayepromise.js":1}],"auth/iframe":[function(require,module,exports){
module.exports=require('67urtb');
},{}],"9joUsL":[function(require,module,exports){
var api, app, auth, aye, config, doAuth, iframe, lastScope, link, popup, url, _get;

config = require('../config');

api = require('../api');

popup = require('./popup');

iframe = require('./iframe');

aye = require("./../../../bower/aye/ayepromise.js");

app = {};

link = {};

lastScope = [];

url = function(scope, hash) {
  if (scope == null) {
    scope = [];
  }
  if (hash == null) {
    hash = 'oauth';
  }
  return "" + config.auth + "?client_id=" + app.id + "&redirect_uri=" + app.uri + "&response_type=token&scope=" + (scope.join(' ')) + "#" + hash;
};

_get = function(interactive, scope) {
  var deffered, oa;
  if (interactive == null) {
    interactive = true;
  }
  deffered = aye.defer();
  oa = interactive ? popup : iframe;
  if (scope) {
    lastScope = scope;
  }
  scope = lastScope;
  link.deffered = deffered;
  return {
    oa: oa,
    scope: scope,
    deffered: deffered
  };
};

doAuth = function(oa, url, deffered) {
  if (!(app.id && app.uri)) {
    deffered.reject('Widgetic must be initialized with client id and redirect uri!');
    return deffered.promise;
  }
  return oa(url, deffered);
};

auth = function() {
  var deffered, oa, scope, _ref;
  _ref = _get.apply(null, arguments), oa = _ref.oa, scope = _ref.scope, deffered = _ref.deffered;
  return doAuth(oa, url(scope), deffered);
};

auth.register = function(scope) {
  var deffered, oa, _ref;
  _ref = _get(true, scope), oa = _ref.oa, scope = _ref.scope, deffered = _ref.deffered;
  return doAuth(oa, url(scope, 'signup'), deffered);
};

auth.setAuthOptions = function(id, uri, root) {
  app.id = id;
  return app.uri = uri;
};

auth.getClientId = function() {
  return app.id;
};

auth.retry = function(response) {
  return auth.apply(this, response.d);
};

auth.connect = function(response) {
  var data;
  data = response.d;
  if (data && data.access_token) {
    api.setTokens(data);
    link.deffered.resolve(api.getStatus());
    return setTimeout(auth.bind(this, false), data.expires_in * 1000 - 1500);
  } else {
    return link.deffered.reject(api.getStatus());
  }
};

module.exports = auth;


},{"../api":"pK1+ma","../config":"ZaiTg0","./../../../bower/aye/ayepromise.js":1,"./iframe":"67urtb","./popup":"JLc0KN"}],"auth/index":[function(require,module,exports){
module.exports=require('9joUsL');
},{}],"JLc0KN":[function(require,module,exports){
var aye, guid, link, options, popup, rwin;

aye = require("./../../../bower/aye/ayepromise.js");

guid = require('../utils/guid');

rwin = window;

link = {};

options = function(width, height) {
  var left, top;
  left = (screen.width - width) / 2;
  top = (screen.height - height) / 2;
  return "location=no,menubar=no,toolbar=no,scrollbars=no,status=no,resizable=no,width=" + width + ",height=" + height + ",left=" + left + ",top=" + top;
};

popup = function(url, deffered) {
  var check, interval, promise, win, _ref;
  promise = deffered.promise;
  if ((_ref = link.win) != null) {
    _ref.close();
  }
  link.win = win = rwin.open(url, "widgetic_popup_" + (guid()), options(500, 496));
  check = function() {
    if (!win || win.closed) {
      clearInterval(interval);
      return deffered.reject('window closed');
    }
  };
  interval = setInterval(check, 50);
  promise.then(function() {
    return win.close();
  });
  return promise;
};

module.exports = popup;


},{"../utils/guid":"EadS8b","./../../../bower/aye/ayepromise.js":1}],"auth/popup":[function(require,module,exports){
module.exports=require('JLc0KN');
},{}],"config":[function(require,module,exports){
module.exports=require('ZaiTg0');
},{}],"ZaiTg0":[function(require,module,exports){
var config, domain, host, o, parse, parsedDomain, protocol, wl, _ref, _ref1;

wl = window.location;

if (!wl.origin) {
  wl.origin = wl.protocol + "//" + wl.hostname + (wl.port ? ':' + wl.port : '');
}

parse = require('./detect/parse');

domain = ((_ref = window.widgeticOptions) != null ? _ref.domain : void 0) || 'widgetic.com';

o = "?lo=" + (encodeURIComponent(wl.origin));

protocol = ((_ref1 = window.widgeticOptions) != null ? _ref1.secure : void 0) === false ? 'http' : 'https';

parsedDomain = parse(domain);

host = parsedDomain.host + (parsedDomain.port ? ':' + parsedDomain.port : '');

config = {
  proxy: "" + protocol + "://" + host + "/sdk/proxy.html" + o + "#proxy",
  popup: "" + protocol + "://" + host + "/sdk/proxy.html" + o + "#popup",
  auth: "" + protocol + "://" + domain + "/oauth/v2/auth",
  composition: "" + protocol + "://" + domain + "/api/v2/compositions/{id}/embed.html" + o,
  widget: "" + protocol + "://" + domain + "/api/v2/widgets/{id}/embed.html" + o,
  editor: "" + protocol + "://" + domain + "/api/v2/editor.html" + o,
  plugin: "" + protocol + "://" + host + "/plugin" + o,
  api: "/api/v2/",
  domain: "https://" + host,
  lo: decodeURIComponent(parse(wl).queryKey.lo || wl.origin)
};

module.exports = config;


},{"./detect/parse":"mM0D7K"}],"constants/events":[function(require,module,exports){
module.exports=require('KcPy++');
},{}],"KcPy++":[function(require,module,exports){
module.exports = {
  COMPOSITION_SAVED: 'save',
  SKIN_SAVED: 'skin-save'
};


},{}],"detect/index":[function(require,module,exports){
module.exports=require('B8S8ON');
},{}],"B8S8ON":[function(require,module,exports){
var config, detect, json, parse, win;

config = require('../config');

parse = require('./parse');

json = require('json3');

win = window;

detect = function(url) {
  var data, hash, hashKey, isOauth, isPopup, isProxy, parsed, query, queryKey, sourceOrigin, type;
  if (win.parent && win.parent === win && !win.opener) {
    return;
  }
  parsed = parse(url);
  hash = parsed.hash;
  hashKey = parsed.hashKey;
  query = parsed.query;
  queryKey = parsed.queryKey;
  isProxy = hash === 'proxy';
  isPopup = hashKey.hasOwnProperty('popup');
  isOauth = hashKey.hasOwnProperty('oauth') || hashKey.access_token;
  if (!(isOauth || isProxy || isPopup)) {
    return;
  }
  if (isOauth) {
    type = 'o';
  }
  if (isProxy) {
    type = 'i';
  }
  if (isPopup) {
    type = 'p';
  }
  data = hash ? hashKey : queryKey;
  sourceOrigin = !isOauth ? config.lo : win.location.origin;
  return (win.opener || win.parent).postMessage(json.stringify({
    d: data,
    t: type
  }), sourceOrigin);
};

detect.parse = parse;

module.exports = detect;


},{"../config":"ZaiTg0","./parse":"mM0D7K","json3":5}],"mM0D7K":[function(require,module,exports){
var parse;

parse = function(str) {
  var i, m, o, uri;
  o = parse.options;
  m = o.parser[(o.strictMode ? "strict" : "loose")].exec(str);
  uri = {};
  i = 14;
  while (i--) {
    uri[o.key[i]] = m[i] || "";
  }
  uri[o.q.name] = {};
  uri[o.key[12]].replace(o.q.parser, function($0, $1, $2) {
    if ($1) {
      return uri[o.q.name][$1] = $2;
    }
  });
  uri[o.h.name] = {};
  uri[o.key[13]].replace(o.h.parser, function($0, $1, $2) {
    if ($1) {
      return uri[o.h.name][$1] = $2;
    }
  });
  return uri;
};

parse.options = {
  strictMode: false,
  key: ["source", "protocol", "authority", "userInfo", "user", "password", "host", "port", "relative", "path", "directory", "file", "query", "hash"],
  q: {
    name: "queryKey",
    parser: /(?:^|&)([^&=]*)=?([^&]*)/g
  },
  h: {
    name: "hashKey",
    parser: /(?:^|&)([^&=]*)=?([^&]*)/g
  },
  parser: {
    strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,
    loose: /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
  }
};

module.exports = parse;


},{}],"detect/parse":[function(require,module,exports){
module.exports=require('mM0D7K');
},{}],"+aqgVi":[function(require,module,exports){
var Root, api, aye, config, css, event, iframe, steps;

css = "#widgetic-root{position:absolute;top:-1000px;left:-1000px;width:0px;height:0px;visibility:hidden;z-index:-1}#widgetic-root iframe{width:0px;height:0px}iframe.widgetic-composition {border: none;width: 100%;height: 100%;}iframe.widgetic-editor {width: 490px; height: 565px; border:none;overflow:hidden}";

config = require('../config');

event = require('../utils/event');

api = require('../api/index');

iframe = require('../auth/iframe');

steps = api.queue.steps;

aye = require("./../../../bower/aye/ayepromise.js");

Root = function() {
  var body;
  body = document.getElementsByTagName('body')[0];
  body.appendChild(this.el = document.createElement('div'));
  this.el.id = "widgetic-root";
  iframe.setRoot(this);
  return this;
};

Root.prototype.createProxy = function() {
  var fail, proxy, timeout;
  if (steps.init) {
    proxy = document.createElement('iframe');
    this.el.appendChild(proxy);
    fail = function() {
      Root._done = null;
      clearTimeout(timeout);
      return console.error('Could not initialize iframe');
    };
    timeout = setTimeout(fail, 10000);
    Root._done = function() {
      api.setProxy(function(message) {
        return proxy.contentWindow.postMessage(message, config.domain);
      });
      console.log("SDK initialized");
      clearTimeout(timeout);
      steps.init();
      return Root._done = steps.init = null;
    };
    proxy.setAttribute('src', config.proxy);
  }
  return this;
};

Root.connect = function() {
  return typeof Root._done === "function" ? Root._done() : void 0;
};

Root.style = function() {
  var head, style;
  head = document.getElementsByTagName('head')[0];
  head.appendChild(style = document.createElement('style'));
  return style.textContent = css;
};

module.exports = Root;


},{"../api/index":"pK1+ma","../auth/iframe":"67urtb","../config":"ZaiTg0","../utils/event":"OZFmFt","./../../../bower/aye/ayepromise.js":1}],"dom/root":[function(require,module,exports){
module.exports=require('+aqgVi');
},{}],"index":[function(require,module,exports){
module.exports=require('tzAnED');
},{}],"tzAnED":[function(require,module,exports){
var Composition, Editor, JSON, Root, UI, Widgetic, api, auth, config, detect, event, hasProxy, initProxy, originRegex, receiver, receivers, whenReady, win;

config = require('./config');

Root = require('./dom/root');

api = require('./api');

auth = require('./auth');

detect = require('./detect');

JSON = require('json3');

event = require('./utils/event');

whenReady = require('./utils/ready');

Composition = require('./UI/composition');

Editor = require('./UI/editor');

UI = require('./UI');

win = window;

hasProxy = false;

receivers = {
  'a': api.request,
  'e': api.response,
  'i': Root.connect,
  'o': auth.connect,
  'u': Composition.connect,
  'ce': Composition.event,
  'w': Editor.connect,
  'ee': Editor.event,
  'p': UI.popup.receiver,
  'r': auth.retry,
  'v': UI.plugin.connect,
  've': UI.plugin.event
};

originRegex = "" + (config.lo.replace(/(http|https)\:/, '')) + "|" + (config.domain.replace(/(http|https)\:/, ''));

originRegex = originRegex.replace(/\./g, '\\.');

originRegex = new RegExp(originRegex);

receiver = function(e) {
  var d, error, _name;
  if (!originRegex.test(e.origin)) {
    return;
  }
  d = e.data;
  try {
    if (typeof d !== "string") {
      return;
    }
    d = JSON.parse(d);
  } catch (_error) {
    error = _error;
    console.warn('Widgetic SDK: error parsing JSON:', d);
    return;
  }
  try {
    return typeof receivers[_name = d.t] === "function" ? receivers[_name](d, e) : void 0;
  } catch (_error) {
    error = _error;
    return console.error('Widgetic SDK: ', error.stack);
  }
};

Widgetic = function() {
  if (typeof win['WidgeticAsyncInit'] === "function") {
    win['WidgeticAsyncInit']();
  }
  event.on(win, 'message', receiver);
  detect(win.location.href);
  Root.style();
  return UI.parse();
};

initProxy = function() {
  var create,
    _this = this;
  if (hasProxy) {
    return;
  }
  create = function() {
    (_this.root = new Root()).createProxy();
    return hasProxy = true;
  };
  if (document.getElementsByTagName('body')[0]) {
    return create();
  } else {
    return whenReady(create);
  }
};

Widgetic.prototype.init = function(client_id, redirect_uri) {
  initProxy();
  if (!(client_id && redirect_uri)) {
    return this;
  }
  auth.setAuthOptions(client_id, redirect_uri);
  return this;
};

Widgetic.prototype.api = function() {
  initProxy();
  return api.apply(this, arguments);
};

Widgetic.prototype.auth = function() {
  return auth.apply(this, arguments);
};

Widgetic.prototype.auth.register = function() {
  return auth.register.apply(this, arguments);
};

Widgetic.prototype.auth.status = function() {
  return api.getStatus.apply(this, arguments);
};

Widgetic.prototype.auth.token = function() {
  return api.accessToken.apply(this, arguments);
};

Widgetic.prototype.auth.disconnect = function() {
  return api.disconnect.apply(this, arguments);
};

Widgetic.prototype.JSON = JSON;

Widgetic.prototype.Queue = api.queue;

Widgetic.prototype.Aye = require("./../../bower/aye/ayepromise.js");

Widgetic.prototype.Event = event;

Widgetic.prototype.GUID = require('./utils/guid');

Widgetic.prototype.pubsub = require("./../../bower/pubsub.js/src/pubsub.js");

Widgetic.prototype.require = require;

Widgetic.prototype.UI = UI;

Widgetic.prototype.EVENTS = require('./constants/events');

Widgetic.prototype.VERSION = '0.5.5';

Widgetic.prototype.debug = {
  timestamp: require('./utils/timestamp')
};

module.exports = Widgetic;


},{"./../../bower/aye/ayepromise.js":1,"./../../bower/pubsub.js/src/pubsub.js":2,"./UI":"4bzqDg","./UI/composition":"aP+Ks/","./UI/editor":"sk8aR+","./api":"pK1+ma","./auth":"9joUsL","./config":"ZaiTg0","./constants/events":"KcPy++","./detect":"B8S8ON","./dom/root":"+aqgVi","./utils/event":"OZFmFt","./utils/guid":"EadS8b","./utils/ready":"IiXnYl","./utils/timestamp":"JpsWip","json3":5}],"utils/event":[function(require,module,exports){
module.exports=require('OZFmFt');
},{}],"OZFmFt":[function(require,module,exports){
var add, rem;

add = 'addEventListener';

rem = 'removeEventListener';

module.exports = {
  on: function(el, type, fn, capture) {
    if (capture == null) {
      capture = false;
    }
    if (el[add]) {
      return el[add](type, fn, capture);
    } else {
      return el.attachEvent("on" + type, fn);
    }
  },
  off: function(el, type, fn, capture) {
    if (capture == null) {
      capture = false;
    }
    if (el[rem]) {
      return el[rem](type, fn, capture);
    } else {
      return el.detachEvent("on" + type, fn);
    }
  }
};


},{}],"EadS8b":[function(require,module,exports){
var guid;

guid = function() {
  var _p8;
  _p8 = function(s) {
    var p;
    p = (Math.random().toString(16) + "000000000").substr(2, 8);
    if (s) {
      return "-" + p.substr(0, 4) + "-" + p.substr(4, 4);
    } else {
      return p;
    }
  };
  return _p8() + _p8(true) + _p8(true) + _p8();
};

module.exports = guid;


},{}],"utils/guid":[function(require,module,exports){
module.exports=require('EadS8b');
},{}],"GkoH8v":[function(require,module,exports){
var nextInit, queue, steps;

queue = require("./../../../bower/queue-async/queue.js")(1);

steps = {};

nextInit = function(next) {
  return steps.init = next;
};

queue.defer(nextInit);

queue.steps = steps;

module.exports = queue;


},{"./../../../bower/queue-async/queue.js":3}],"utils/queue":[function(require,module,exports){
module.exports=require('GkoH8v');
},{}],"IiXnYl":[function(require,module,exports){
var ready;

ready = function(fn) {
  if (document.readyState === 'complete') {
    fn();
    return;
  }
  return document.addEventListener('DOMContentLoaded', fn);
};

module.exports = ready;


},{}],"utils/ready":[function(require,module,exports){
module.exports=require('IiXnYl');
},{}],"JpsWip":[function(require,module,exports){
var timestamp;

try {
  timestamp = window.require('spine/utils/timestamp');
} catch (_error) {
  timestamp = function() {};
}

module.exports = timestamp;


},{}],"utils/timestamp":[function(require,module,exports){
module.exports=require('JpsWip');
},{}]},{},[6])