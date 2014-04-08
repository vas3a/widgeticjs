ready = (fn) -> 
  if document.addEventListener
    document.addEventListener 'DOMContentLoaded', fn
  else
    document.attachEvent 'onreadystatechange', ->
      if document.readyState is 'interactive'
        fn()

module.exports = ready