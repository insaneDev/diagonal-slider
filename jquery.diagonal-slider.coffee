_SKEW_ANGLE = 33
_ANGLE_TEXT = -_SKEW_ANGLE
_PERCENT_DISTRIBUTION_CLIP = 0.3
_PERCENT_DISTRIBUTION_CONT = 1 - _PERCENT_DISTRIBUTION_CLIP*2
_RADIAN = 180/Math.PI
_MAX = Math['max'];
_MIN = Math['min'];
_SIN = Math['sin'];
_ASIN = Math['asin'];
_COS = Math['cos'];
_ACOS = Math['acos'];

log = () ->
	console.log Array::slice.call(arguments) if window['console']
	true

debug = () ->
	console.log Array::slice.call(arguments) if window['console']
	true

unless window.getComputedStyle
  window.getComputedStyle = (el, pseudo) ->
    @el = el
    @getPropertyValue = (prop) ->
      re = /(\-([a-z]){1})/g
      prop = "styleFloat"  if prop is "float"
      if re.test(prop)
        prop = prop.replace(re, ->
          arguments_[2].toUpperCase()
        )
      (if el.currentStyle[prop] then el.currentStyle[prop] else null)

    this

class Css3Support
	vendors : ['-webkit-','-o-','-ms-','-moz-','']
	### Css3 quick support check###
	constructor : () ->
		el = if @testElement then @testElement else (@testElement = document.createElement('p'))
		document.body.insertBefore(el, null) 
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
			@image = img
		@			

	w: () -> @canvas.width
	h: () -> @canvas.height
	
	getContext: () -> @context
	
	getImageData: () -> @context.getImageData(0,0,@w(),@h())
	putImageData: (imageData) ->@context.putImageData(imageData,0,0)

	getRect: (rect, crop) ->
		@context.save()
		@context.drawImage(@image, rect.x, rect.y, rect.width, rect.height, crop.x, crop.y, crop.width, crop.height)
		result = @getImage()
		@context.restore()
		result

	getImage: (format = 'image/png') -> 
		@canvas.toDataURL(format)

	drawAndGetImage: (image) ->
		@context.drawImage(image, 0, 0, image.width, image.height, 0, 0, @w(), @h())
		@getImage()

	imageToDataUrl : (image, w = image.width, h = image.height) ->
		n = new Canvas(w, h, image)
		n.getImage()

	canvasApply: (obj)->
		do (context = @context) ->
			context[e] = i for e, i of obj
		@

	drawTitle: (text, bold, font, size, x=0, y=0, angle)->
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
			#_ANGLE_TEXT*Math.PI/180
			@context.rotate(angle)
			#Then translate back to draw in the right place!
			@context.translate(-tx,-ty)
		
		@context.fillText(text, x, y)
		#This will un-translate and un-rotate the canvas
		@context.restore()
		@
	
	clipImageInDiagonal: (mode = 'paralellogram', percentTriangleStart = _PERCENT_DISTRIBUTION_CLIP, rectCrop = null, rectCrop2 = null ) ->

		p0 =
				x: 0
				y: 0
		
		p1 = x: @w(), y: 0
		
		clipPathPoints = []

		@context.save()
		@context.beginPath()

		wside = percentTriangleStart * @w()
		
		if mode is 'paralellogram'

			p1 = 
				x : wside
				y : @h() 

			@context.moveTo(0, 0)

			clipPathPoints = [
				[p1.x, 0],
				[@w(), 0],
				[@w()-p1.x, @h()],
				[0, @h()],
				[p1.x, 0]
			]

		else if mode is 'gun'
			
			p1 = 
				x : wside
				y : @h()

			@context.moveTo(0, 0)

			clipPathPoints = [
				[0, 0],
				[@w(), 0],
				[@w()-p1.x, @h()],
				[0, @h()],
				[0, 0]
			]

		for p in clipPathPoints
			@context.lineTo(p[0], p[1])

		@context.closePath()
		@context.save()
		@context.clip()

		#@context.drawImage(@image, 0, 0)

		#imageObj, sourceX, sourceY, sourceWidth, sourceHeight, destX, destY, destWidth, destHeight
		try
			@context.drawImage(@image, 0, 0, @image.width, @image.height, 0, 0, @w(), @h())
		catch e
			debug(e, e.message, @image)

		@context.restore()
		@


class DiagonalSlider
	canvas: null
	
	defaults:
		slideOpening: 'full' #[full, partial]
		width: 1100
		height: 365
		angleClip: null
		opening: 'auto'
		fontSize: '32px'
		fontFamily: 'Arial'
		fontColor: '#FFFFFF'
	
	reset: (callbackEach, callbackComplete, $filter = null, $skipTransition = false) ->

		self = @

		self.scope
			.find('.rubber').show()

		currentIndex = self.scope.data('currentIndex')

		supportTransform = self.css3.supports('transform')

		slides = self.slides

		#slides.sort( (i) -> i is currentIndex )

		#if $filter isnt null
		#	slides = slides.filter( (index) -> $filter(index, @) )

		slides.removeClass('active')

		transitionCntSlide = slides.length		

		onSlideTransitionEnds = (current = transitionCntSlide) ->
			debug('onSlideTransitionEnds', current)
			if current is 0 # reset ends successfully
				self.scope
					.removeClass('open')
					.addClass('closed')
					.data('currentIndex', -1)

		onSlideTransitionEnds()

		slides.each( (i, slideElement) ->

			slide = $(slideElement)

			tx = slide.data('origen_x')
			ty = 0

			transitionDuration = 800
			transform = self._conditionalCssLeft(tx)
			transform['background-image'] = slide.data('clippedImageData')

			pcssl = self._parseCssLeft(slide)

			if Math.floor(pcssl) is Math.floor(tx) or $skipTransition
				#we are allready there
				callbackEach.apply(self, [i, slide]) if callbackEach
				return slide

			if supportTransform

				debug('slides e', i, slideElement, pcssl,  tx)

				slide
					.addClass('animate')
					.one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend', (event) -> 
						transitionCntSlide--
						onSlideTransitionEnds()
						slide.removeClass('animate')
						if callbackEach
							callbackEach.apply(self, [i, slide])
						@
					)
					.css(transform)
				@
			else

				slide
					.animate(transform, transitionDuration, () ->
						transitionCntSlide--
						onSlideTransitionEnds()
						callbackEach.apply(self, [i, slide]) if callbackEach
						@
					)
				@
		)
		
		@

	slidesgt: (i) -> @slides.slice(++i)
	slideslt: (i) -> @slides.slice(0, --i)
	getSlides: (i) -> @slides

	restore: (c = null) -> @reset(c)
	close: (options, c = null) -> @reset(c)

	_parseCssLeft: (el, property = 'transform') ->
		css3 =  new Css3Support()
		cssKey = css3.supports(property)
		value = null
		if cssKey isnt null
			transform = $(el).css(cssKey.property)
			value = parseInt(transform.replace(/[\D]+/,'').split(',')[4])
		else
			value = parseInt($(el).css('left'))
		value

	_conditionalCssLeft: (x) ->
		css3 =  new Css3Support()
		property = 'transform'
		css3supports = css3.supports(property)
		transform = if css3supports then css3.getCssPropertyVendor(property, "translate3d(" + x + "px, " + 0 + ", 0 )") else {x: left}
		transform

	open: (index) ->

		self = @

		isOpen = @scope.is('.open')	
		isClosed = !isOpen
		currentIndex = @scope.data('currentIndex')
		
		if currentIndex is index
			@close
				force: true
			return false

		@slides
			.removeClass('active')

		opening = @defaults.opening
		
		current = @slides.eq(index)

		@scope.find('.rubber').hide()

		if self.defaults.slideOpening is 'full'
			slice = @slides
		else
			slice = @slidesgt(index)
			current = slice.first()

		img = current.find('img')

		reference = img.data('ref')
		container = current.find('.dcontent-inner');
		isExternal = if reference then reference.indexOf('.')>-1 or reference.indexOf('#')>-1 else false
		
		if isExternal
			container.empty().load(reference)
		else
			container.empty().append($(reference))

		init_x = parseInt(current.css('left')) + current.width() * _PERCENT_DISTRIBUTION_CLIP

		css3supports = self.css3.supports('transform')

		animateTransition = (el, i, skip, css3supports) ->

			dhis = $ el

			origen_x = parseInt(dhis.data('origen_x'))

			#outsideViewport = (if i < index then 1 else -1) * (self.defaults.width + dhis.width())
			outsideViewport = origen_x + ((if i > index then 1 else -1) * dhis.width())

			transform = self._conditionalCssLeft(outsideViewport)

			if css3supports
				dhis
					.addClass('animate')
					.css(transform)
					.one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend', (event) -> true )
			else
				dhis
					.css(transform)

			self.scope.trigger('dslider-change', [null])

		filterFunction = (jor, el) -> jor isnt index

		current
			.removeClass('animate')
			#.css('background-image', current.data('background-css-origin'))

		#.removeClass('open')

		l = self.slides.length-1
		slidesCountTransitioning = self.slides.length-1

		@reset( (ii, transitionSlide) ->

			isntMe = current.get(0) isnt transitionSlide.get(0)

			if isntMe

				self.scope.trigger('dslider-before-change', [self, ii, transitionSlide])
				animateTransition(transitionSlide, ii, index, css3supports )
				
				#for j in [0..l]
				#	self.scope.removeClass('dbgi_' + j )

				debug('isntMe', ii, transitionSlide, slidesCountTransitioning--)
			else
				debug('isMe', ii, transitionSlide, slidesCountTransitioning--)

				for j in [0..l]
					self.scope.removeClass('dbgi_' + j )
				
				self.scope.addClass('dbgi_' + ii )
				self.scope.data('currentIndex', ii)

				transform = self._conditionalCssLeft(0)
				transform.left = 0
				transform['background-image'] = transitionSlide.data('clippedImageData')

				transitionSlide
					.addClass('animate')
					.addClass('active')
					.css(transform)

			if slidesCountTransitioning is 0 #transition open complete
				self.scope
					.removeClass('closed')
					.addClass('open')			
		)

		

		@

	handleClickEvent: (event, index, ref) ->
		@open(index)
		true
	
	constructor: (@scope, options) ->

		self = @

		self.css3 =  new Css3Support()

		defaults = self.defaults = $.extend(@defaults, options)

		holder = $('ul,ol', @scope)
		@slides = slides = holder.children('li')
		slidesCount = slides.size()

		sliderWidth = defaults.width
		sliderHeight = defaults.height		

		if self.defaults.opening is 'auto'
			computedOpening = _MAX(sliderWidth/slidesCount, sliderWidth/6)
			self.defaults.opening = computedOpening
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
			imagej = me.find('img').height(sliderHeight)
			image = imagej.get(0)

			btnClose = $('<a href="" class="close-btn"></a>')
			btnClose
				.click( (event) ->
					event.preventDefault()
					event.stopPropagation()
					self.close()
					self.scope.data('currentIndex', 0)
				)

			#slice = opening + opening*(1+degs[3])
			#how big will be the rubber and the sliced/cropped image
			slice = opening + opening*(1+_PERCENT_DISTRIBUTION_CLIP)

			#Trigo
			#degs = do (width = sliderWidth, height = sliderHeight, f = _PERCENT_DISTRIBUTION_CLIP) ->
			degs = do (width = slice, height = sliderHeight, f = _PERCENT_DISTRIBUTION_CLIP) ->

				aw = width * f
				op = height
				ah = Math.sqrt(Math.pow(aw,2) + Math.pow(op,2))

				f1 = op/ah
				f2 = aw/ah
				
				angle1 = _RADIAN * _ASIN(f1)
				#angle2 = _RADIAN * _ASIN(f2)
				angle2 = 90 - angle1

				[angle1, angle2, f1, f2]

			#debug('degs', slice, degs)

			clone = null
			clone  = do () ->
				exists = me.find('.dcontent')
				if exists.length > 0 then exists else $('<div></div>').addClass('diagonal dcontent clearfix').append('<div class="dcontent-inner"></div>')
			
			me.append(btnClose)

			if transform and index > 0

				#init_x = opening
				init_x = 0

				transformDegs = 'skew(-' + degs[1] + 'deg)'
				tstyle = transform.vendor + 'transform-style'
				tproperty = transform.property

				#absolute
				abs_leftpos = init_x + (opening - opening * degs[1]/100)
				#relative
				rel_leftpos = init_x + (opening * (index+degs[1]/100))

				dl = $('<div></div>').addClass('rubber').attr('for', index)
				
				dl					
					.css(tproperty,transformDegs)
					.css(tstyle,'preserve-3d')
					.css					
						height: sliderHeight * 1.5
						width: opening
						#background: 'rgba(255, 255, 255, 0.5)'
						left: rel_leftpos
						position: 'absolute'
						zIndex: ++zin
						top: -50
						cursor: 'pointer'

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
						#debug(index)
						self.handleClickEvent.apply(self, [event, index, me])
					)
				me.parent().append(dl)
			else
				items = [1..20]
				for i in items.length
					dl = $('<div></div>')
					dl.css
						width: opening
						height: items.length / sliderHeight
					
					me.append(dl)

			leftReference = 0

			if index is 0
				leftReference = origen_x = index * opening
				csstransform = self._conditionalCssLeft(origen_x)
				me
					.addClass('first')
					.data('origen_x', origen_x)
					.css(csstransform)
				
				hasSettedLeftProp = true

			if index is slidesCount-1
				me.addClass('last')

			wtotal+= dw

			if not hasSettedLeftProp

				leftReference = tleft = index * opening
				csstransform = self._conditionalCssLeft(tleft)
				me
					.data('origen_x', tleft)
					.css(csstransform)


			imagej.hide().load( whenImageIsLoaded = () ->
				
				dis = $(@)
				
				xstart = leftReference
				
				rectcanvas = new Canvas(slice, sliderHeight, image)

				#imageObj, sourceX, sourceY, sourceWidth, sourceHeight, destX, destY, destWidth, destHeight
				sourceRect = {x:0,y:0,width:@.width,height:@.height}
				destRect = {x:-xstart,y:0,width:sliderWidth,height:sliderHeight}
				
				rect = rectcanvas.getRect(sourceRect, destRect)
				rectData = rectcanvas.getImageData()

				imgdata = new Canvas(sliderWidth, sliderHeight)
				justTheImageData = imgdata.drawAndGetImage(image)

				sliceImg = new Image()
				sliceImg.onload = () ->
					
					dcanvas = new Canvas(@.width, @.height, @)
					#dcanvas.putImageData(rectData)
					
					#justTheImageData = dcanvas.imageToDataUrl(@, sliderWidth, sliderHeight)
					

					clipMode = if index is 0 then 'gun' else 'paralellogram'
					
					dcanvas.clipImageInDiagonal(clipMode, _PERCENT_DISTRIBUTION_CLIP)				

					clippedImageData = dcanvas.getImage()

					me.data('clippedImageData', clippedImageData)

					fs = parseInt(defaults.fontSize)
				
					if (alt = imagej.attr('alt')) != null
						dcanvas
							.canvasApply(labelOpts)
							.drawTitle(alt, 'normal', defaults.fontFamily, fs, (dw * _PERCENT_DISTRIBUTION_CLIP)-fs, sliderHeight, degs[0] )

					do ( eindex = index ) -> 
					
						style = '<style>'
						
						style+= '.' + cls1 + '{ ';
						style+= 'background-image: url(' + clippedImageData  + ');';
						#style+= 'background-position: -' + leftReference  + 'px 0px;';
						style+= '}'

						style+= '.' + cls2 + '{ ';
						style+= 'background-image: url(' + justTheImageData  + ');';
						#style+= 'background-position: -' + leftReference  + 'px 0px;';
						style+= '}'

						style+= '.' + cls3 + '{ ';
						style+= 'background-image: url(' + rect  + ');';
						#style+= 'background-position: -' + leftReference  + 'px 0px;';
						style+= '}'

						style+= '</style>'

						head = $('head:first')
						head.append(style)

				sliceImg.src = rect

				$('#im').attr('src',rect)

				cls1 = 'dbg_' + index
				cls2 = 'dbgi_' + index
				cls3 = 'dbgc_' + index
				
				classname = [cls1, cls2, cls3]

				backgroundCss =  'url(' + @.src  + ')'

				#me.addClass(classname)
				clone.addClass(classname[0])
				clone					
					.insertAfter(@)
					.css
						#background : tiltCss
						height : dis.height()
						width : dis.width()
				#me.css
				#	background: backgroundCss				

				me.data('background-origin', @.src)
				me.data('background-css-origin', backgroundCss)
			)

			me
				.css('cursor', 'pointer')
				.css('z-index', zin-- )
				.click((event) ->
					slides.removeClass('active')
					me.toggleClass('active')
					self.handleClickEvent.apply(self, [event, index, me])
				)

		)

		holder.css
			width: wtotal + 'px'

if typeof(@.jQuery) != null
	$.fn.diagonalSlider = (options = {} ) ->
		selection = $(@)
		args = Array.prototype.slice.call(arguments)
		isMethodCall = options isnt null and typeof(options) is "string"
		methodResult = null

		if isMethodCall
			methodResult = do () ->
				diagonalSlider = selection.data('dslider')
				method = args.shift()
				methodReference = if method isnt null then diagonalSlider[method] else false
				if methodReference
					try
						return methodReference.apply(diagonalSlider, args)
					catch e
						return null
		else
			selection.each( () ->
				me = $(@)
				me
					.addClass('dslider')			
					.data('dslider', (instance = new DiagonalSlider(me, options)))

				me
			)
		if methodResult isnt null then methodResult else selection
		@
@