ready = (fn) -> 
  if document.readyState is 'complete' or document.readyState is 'interactive'
    fn()
    return

  if document.addEventListener
    document.addEventListener 'DOMContentLoaded', fn
  else
    document.attachEvent 'onreadystatechange', ->
      if document.readyState is 'interactive'
        fn()

module.exports = ready