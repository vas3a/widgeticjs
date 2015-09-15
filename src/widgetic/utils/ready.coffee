ready = (fn) -> 
  if document.readyState in ['interactive', 'complete']
    fn()
    return

  document.addEventListener 'DOMContentLoaded', fn

module.exports = ready