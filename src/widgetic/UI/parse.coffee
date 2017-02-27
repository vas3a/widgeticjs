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

resizeHolderTemplate = (id, inline, styles, forIframeEmbed) ->
	inlineStyle = if inline then 'display:inline-block;vertical-align:middle;' else ''
	if forIframeEmbed
		"<div style=\"width:100%;#{ inlineStyle }#{ styles.wrapStyle or '' }\">" +
			"<div style=\"position:relative; padding: 0;#{ styles.holdStyle or '' }\">" +
				"$$$" +
			"</div>" +
		"</div>"
	else
		"<div class=\"wdgtc-wrap\" data-wdgtc-id=\"#{ id }\" style=\"width:100%;#{ inlineStyle }#{ styles.wrapStyle or '' }\">
			<div class=\"wdgtc-holder\" style=\"position:relative; padding: 0;#{ styles.holdStyle or '' }\">
			</div>
		</div>"

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
	'fill-width': (width, height) ->
		ratio = height * 100 / width;
		{
			holdStyle: "padding-top: #{ ratio }%;"
		}
	'fill': (width, height) ->
		{
			wrapStyle: "height: 100%"
			holdStyle: "height: 100%;min-height:#{ height }px"
		}
}

###
 Matches [widgetic-some-widget id=12345 width=200 height=100 inline] shortcodes
 and converts them to embed syntax
###
parseShortcodes = ->
	shortcode = /\[widgetic\-([-\w]+) *((?: [-\w]+(?:=.*?)?)+)\]/ig
	extraWhitespace = /\s+/g
	toAnchorTag = (_, widget, attributes) ->
		htmlAttributes = attributes.trim().replace(extraWhitespace, ' ')
			.split(' ')
			.map((pair) -> 'data-' + pair)
			.join(' ')
		return '<a href="https://widgetic.com/widget/' + widget + '/" class="widgetic-composition" ' + htmlAttributes + '></a>'

	for parentEl in document.querySelectorAll("body, body *")
		continue if parentEl.nodeName in ['HEAD', 'META', 'LINK', 'SCRIPT', 'TITLE']
		children = parentEl.childNodes

		for el in children
			continue unless el.nodeType is 3
			value = el.nodeValue
			newValue = value.replace shortcode, toAnchorTag
			if value != newValue
				newEl = document.createElement 'div'
				newEl.innerHTML = newValue
				parentEl.replaceChild(newEl, el)

parse = -> whenReady ->
	parseShortcodes()
	compositionEls = document.querySelectorAll('.widgetic-composition')
	for el in compositionEls
		embed(el)
	return

###
Generates the wrapping html for the embed iframe
###
parse.wrapperHtml = (options, forIframeEmbed = false) ->
	styles = stylesFactory[options.resize](options.width, options.height)
	resizeHolderTemplate(options.composition, options.inline, styles, forIframeEmbed)

embed = (el) ->
	options = {
		composition: el.getAttribute('data-id')
		width:  el.getAttribute('data-width') || 300
		height: el.getAttribute('data-height') || 200
		resize: el.getAttribute('data-resize') || defaultResizeStyle
		brand_pos: el.getAttribute('data-brand') || 'bottom-right'
		branding: el.hasAttribute('data-branding')
		inline: el.hasAttribute('data-inline')
		autoscale: el.getAttribute('data-autoscale') || 'on'
	}

	return unless options.composition
	options.resize = defaultResizeStyle unless stylesFactory[options.resize]

	el.insertAdjacentHTML('afterbegin', parse.wrapperHtml(options))
	el = replaceParentWithChild(el)
	holder = getHolder(el)
	options.iframeStyle = 'position:absolute;top:0;left:0;width:100%;height:100%;'
	composition = new Widgetic.UI.composition(holder, options.composition, options)

module.exports = parse
