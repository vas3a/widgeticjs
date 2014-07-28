whenReady = require '../utils/ready'

defaultResizeStyle = 'allow-scale-down'

replaceParentWithChild = (parent) ->
	child = parent.children[0]
	grandparent = parent.parentNode

	parent.removeChild(child)

	frag = document.createDocumentFragment()
	frag.insertBefore(child, null)

	grandparent.insertBefore(frag, parent)
	grandparent.removeChild(parent)
	return child

getHolder = (wrapper) ->
	wrapper.children[0]

resizeHolderTemplate = (id, styles) ->
	"<div class=\"wdgtc-wrap\" data-wdgtc-id=\"#{ id }\" style=\"width:100%;#{ styles.wrapStyle or '' }\">
		<div class=\"wdgtc-holder\" style=\"position:relative; padding: 0;#{ styles.holdStyle or '' }\">
		</div>
	</div>";

stylesFactory = {
	'fixed': (width, height) -> 
		ratio = height * 100 / width;
		{
			wrapStyle: "max-width: #{ width }px; min-width: #{ width }px;"
			holdStyle: "padding-top: #{ ratio }%;"
		}
	'allow-scale-down': (width, height) -> 
		ratio = height * 100 / width;
		{
			wrapStyle: "max-width: #{ width }px;"
			holdStyle: "padding-top: #{ ratio }%;"
		}
	'fixed-height': (width, height) -> 
		{
			holdStyle: "height: #{ height }px; padding-top: 0;"
		}
	'fill': (width, height) -> 
		ratio = height * 100 / width;
		{
			holdStyle: "padding-top: #{ ratio }%;"
		}
}

parse = -> whenReady ->
	compositionEls = document.querySelectorAll('.widgetic-composition')
	for el in compositionEls
		embed(el)
	return
		
embed = (el) ->
	options = {
		id:     el.getAttribute('data-id')
		width:  el.getAttribute('data-width') || 300
		height: el.getAttribute('data-height') || 300
		resize: el.getAttribute('data-resize') || defaultResizeStyle
		brand_pos: el.getAttribute('data-brand') || 'bottom-right'
	}

	return unless options.id
	options.resize = defaultResizeStyle unless stylesFactory[options.resize]

	styles = stylesFactory[options.resize](options.width, options.height)
	el.insertAdjacentHTML('afterbegin', resizeHolderTemplate(options.id, styles))
	el = replaceParentWithChild(el)
	holder = getHolder(el)
	composition = new Blogvio.UI.composition(holder, options.id, options.brand_pos)
	composition._iframe.setAttribute 'style', 'position:absolute;top:0;left:0;width:100%; height:100%;'

module.exports = parse