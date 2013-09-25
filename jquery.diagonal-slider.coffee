_ANGLE_TEXT = -55
_PERCENT_DISTRIBUTION_ANGLE = 25
_PERCENT_DISTRIBUTION_CLIP = 0.25
_PERCENT_DISTRIBUTION_CONT = 1 - _PERCENT_DISTRIBUTION_CLIP*2
_RADIAN = 180/Math.PI
_SIN = Math['sin'];
_COS = Math['cos'];

class Css3Support
	vendors : ['-webkit-','-o-','-ms-','-moz-','']
	### Css3 quick support check###
	constructor : () ->
		p = document.createElement('p')
		@testElement = p
		document.body.insertBefore(@testElement, null) 
	supports: (key) ->
		for v, e in @vendors
			return {vendor: v, property: v+key} if window.getComputedStyle(@testElement).getPropertyValue(v+key)
		false
	getCssPropertyVendor:(baseProperty, value) ->
		i = {}
		for v, e in @vendors
			i[v+baseProperty] = value
		i

class Canvas
	constructor: (w, h, img = null) ->
		@canvas = document.createElement('canvas')
		@canvas.width = w
		@canvas.height = h
		@context = @canvas.getContext('2d')

		if img isnt null
			@context.drawImage(img, 0, 0)

	w: () -> @canvas.width
	h: () -> @canvas.height
	
	getContext: () -> @context
	getImage: (format = 'image/png') -> @canvas.toDataURL(format)

	imageToDataUrl : (image, w=image.width, h=image.height) ->
		n = new Canvas(w, h, image)
		n.getImage()

	canvasApply: (obj)->
		do (context = @context) ->
			context[e] = i for e, i of obj
		@

	drawTitle: (text, bold, font, size, x=0, y=0)->
		#metric will receive the measures of the text
		metric = @context.measureText(text, bold, font, size) 
		#this will "save" the normal canvas to return to
		@context.save()
		if true
			#These two methods will change EVERYTHING
			#drawn on the canvas from this point forward
			#Since we only want them to apply to this one fillText,
			#we use save and restore before and after

			#We want to find the center of the text (or whatever point you want) and rotate about it
			tx = x - (metric.width/2)
			ty = y + size 

			#Translate to near the center to rotate about the center
			@context.translate(tx,ty)
			#Then rotate...
			@context.rotate(_ANGLE_TEXT*Math.PI/180)
			#Then translate back to draw in the right place!
			@context.translate(-tx,-ty)
		@context.fillText(text, x, y)
		#This will un-translate and un-rotate the canvas
		@context.restore()
		@
	
	clipImageInDiagonal: (imageElement, mode = 45, bothSides = false) ->

		p0 = x: 0, y: @h()
		p1 = x: @w(), y: 0

		@context.save()
		@context.beginPath()
		
		if mode is 'trapecy'

			p0 =
				x: 0
				y: 0

			p1 = 
				x: Math.abs(@w() * _SIN(_PERCENT_DISTRIBUTION_ANGLE))
				y: Math.abs(@h() * _COS(_PERCENT_DISTRIBUTION_ANGLE))

			wside = _PERCENT_DISTRIBUTION_CLIP * @w()
			
			###
				@context.moveTo(0, 0)
				@context.lineTo(wside, 0)
				@context.lineTo(@w(), 0)
				@context.lineTo(@w()-wside, @h())
				@context.lineTo(0, @h())
				@context.lineTo(wside, 0)
			###

			clipPathPoints = [
				[p1.x, 0],
				[@w(), 0],
				[@w()-p1.x, @h()],
				[0, @h()],
				[p1.x, 0],
			]

			@context.moveTo(0, 0)

			for p in clipPathPoints
				@context.lineTo(p[0], p[1])

			console.log('clipPathPoints', p1, clipPathPoints)

		if mode is 45
			@context.moveTo(p0.x, p0.y)
			@context.lineTo(p1.x, p1.y)
			@context.lineTo(0, 0)

		@context.closePath()
		@context.save()
		@context.clip()

		@context.drawImage(imageElement, 0, 0)

		@context.restore()
		@


class DiagonalSlider
	canvas: null
	
	defaults:
		slideOpening: 'full' #[full, partial]
		width: 960
		height: 300
		angleClip: _PERCENT_DISTRIBUTION_ANGLE
		opening: 'auto'
		fontSize: '32px'
		fontFamily: 'Arial'
		fontColor: '#FFFFFF'
	
	backToOrigen: (callback) ->

		self = @

		self.slides.removeClass('active').each( (i) ->
			slide = $(@)
			tx = slide.data('origen_x')
			ty = 0
			transform = if self.css3.supports('transform') then self.css3.getCssPropertyVendor('transform', "translate(" + tx + "px, " + ty + ", 0 )") else {left: tx}
			#console.log transform
			slide
				.stop(false, false)
				.css transform
		)

		callback.apply(@, null) if callback
		@

	handleClickEvent: (event, index, ref) ->

		self = @
		
		if @scope.data('currentIndex') is index
			@scope.data('currentIndex', 0)
			@backToOrigen(null)
			return false

		@slides.removeClass 'active'

		opening = @defaults.opening
		
		current = @slides.eq(index)

		if self.defaults.slideOpening is 'full'
			prev = @slides.eq(index)
			prev
				.addClass('active')
				.css('left', 0)
				.css('background', prev.data('background-css-origin'))
			slice = @slides.not(prev)			
		else
			slice = @slides.filter(':gt(' + (index-1) + ')')
			prev = slice.first().addClass('active')

		img = prev.find('img')

		reference = img.attr('data-ref')
		
		if reference.indexOf('.')>-1 or reference.indexOf('#')>-1
			prev.find('.diagonal').append($(reference))
		else
			prev.find('.diagonal').load(reference)

		init_x = parseInt(prev.css('left')) + prev.width() * _PERCENT_DISTRIBUTION_CLIP

		@backToOrigen( () ->

			css3supports = self.css3.supports('transform')
			
			animateTransition = (i) ->

				dhis = $ @

				outsideViewport = (if i > index then 1 else -1) * 3 * dhis.width()

				tx = if self.defaults.slideOpening is 'full' then outsideViewport else init_x + (i*opening)
				ty = 0
				
				transform = if css3supports then self.css3.getCssPropertyVendor('transform', "translate3d(" + tx + "px, " + ty + ", 0 )") else {left: tx}

				#console.log 'animateTransition', i, index, outsideViewport

				dhis.addClass 'animate'
				dhis.css transform

				self.scope.trigger('dslider-change', [null])

			slice.filter(':gt(' + index + ')').each animateTransition
			slice.filter(':lt(' + index + ')').each animateTransition
			
			@scope.data('currentIndex', index)

			self.scope.trigger('dslider-before-change', [null])

		)
		
		true
	
	constructor: (@scope, options) ->

		self = @

		self.css3 =  new Css3Support()

		defaults = self.defaults = $.extend(@defaults, options)

		holder = $('ul,ol', @scope)
		@slides = slides = holder.children()
		slidesCount = slides.size()
		

		sliderWidth = defaults.width
		sliderHeight = defaults.height		

		if self.defaults.opening is 'auto'
			self.defaults.opening = sliderWidth/slidesCount
		opening = defaults.opening

		
		wtotal = 0

		@scope
			.css
				width : sliderWidth
				height : sliderHeight
			.data('currentIndex', 0)

		holder.addClass('clearfix')
		
		slides.css('width', sliderWidth)

		zin = 100 + slidesCount

		labelOpts =
			font : 'normal ' + defaults.fontSize + ' ' + defaults.fontFamily
			fillStyle : defaults.fontColor

		css3 = new Css3Support()
		transform = css3.supports('transform')

		slides.each( (index, el) ->
			me = $(@)
			dw = me.width()
			dh = me.height()
			clone = $('<div></div>').addClass('diagonal')

			imagej = me.find('img').height(sliderHeight)
			image = imagej.get(0)
			dcanvas = new Canvas(image.width, image.height, image)

			imagej.hide().load(() ->
				
				dis = $(@)
				
				justImage = dcanvas.imageToDataUrl(@)
				dcanvas.clipImageInDiagonal(image, 'trapecy', index > 1)
				dataUrl = dcanvas.getImage()

				console.log('ready and set')

				tiltCss = 'transparent url(' + dataUrl  + ') no-repeat center top'				
				backgroundCss =  'url(' + @.src  + ')'

				clone					
					.insertAfter(@)
					.css
						background : tiltCss
						height : dis.height()
						width : dis.width()
				#me.css
				#	background: backgroundCss

				me.data('background-origin', @.src)
				me.data('background-css-origin', backgroundCss)
			)

			if transform and index > 0
				transformDegs = 'rotate(' + self.defaults.angleClip + 'deg)'
				tstyle = transform.vendor + 'transform-style'
				tproperty = transform.property

				dl = $('<div></div>').addClass('rubber')
				
				dl					
					.css(tproperty,transformDegs)
					.css(tstyle,'preserve-3d')
					.css					
						height: sliderHeight * 1.5
						width: opening * 0.7
						#background: 'rgba(255, 255, 255, 0.5)'
						position: 'absolute'
						zIndex: index+3+100
						top: -50
						cursor: 'pointer'

				if index > 0
					dl.css ({left: (dw * _PERCENT_DISTRIBUTION_CLIP) - opening })
				else
					dl.css ({left: dw * _PERCENT_DISTRIBUTION_CLIP })

				dl
					.bind('mouseover', (event) ->
						me.toggleClass('d-hover')
						#self.handleClickEvent.apply(self, [event, index, me])
					)
					.click((event) ->
						event.preventDefault()
						event.stopPropagation()
						slides.removeClass('active')
						me.toggleClass('active')
						self.handleClickEvent.apply(self, [event, index, me])
					)
				me.append(dl)
			else
				items = [1..20]
				for i in items.length
					dl = $('<div></div>')
					dl.css
						width: opening
						height: items.length / sliderHeight
					me.append(dl)

			if index is 0
				origen_x = -(dw * _PERCENT_DISTRIBUTION_CLIP)
				me
					.addClass('first')
					.data('origen_x', origen_x)
					.css('left', origen_x + 'px' )
				
				hasSettedLeftProp = true

			if index is slidesCount-1
				me.addClass('last')

			wtotal+= dw

			fs = parseInt(defaults.fontSize)
			dcanvas
				.canvasApply(labelOpts)
				.drawTitle(alt, 'normal', defaults.fontFamily, fs, (dw * _PERCENT_DISTRIBUTION_CLIP)-fs, sliderHeight ) if (alt = imagej.attr('alt')) != null
			
			if not hasSettedLeftProp

				tleft = index * opening
				me
					.data('origen_x', tleft)
					.css('left', tleft + 'px' )

			me
				.css('cursor', 'pointer')
				.css('z-index', index+1+100 )
				.click((event) ->
					slides.removeClass('active')
					me.toggleClass('active')
					self.handleClickEvent.apply(self, [event, index, me])
				)

		)

		holder.css
			width: wtotal + 'px'

if typeof(@.$) not undefined
	$.fn.diagonalSlider = (options = {} ) ->
		selection = $(@)
		isMethodCall = typeof(options) is "string"
		selection.each( () ->
			me = $(@).addClass('dslider')			
			instance = new DiagonalSlider(me, options)
			me.data('diagonalSlider', instance)
			me
		)
		selection
@.CCanvas = Canvas