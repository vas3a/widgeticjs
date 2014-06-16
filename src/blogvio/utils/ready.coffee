ready = (fn) -> 
  if document.readyState is 'complete'
    fn()
    return

  document.addEventListener 'DOMContentLoaded', fn

module.exports = ready