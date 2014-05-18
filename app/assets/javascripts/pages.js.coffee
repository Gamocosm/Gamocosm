# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$ ->
	$root = $('html, body')
	$('a[href*=#].anchor-page').on('click', (event) ->
		event.preventDefault()
		href = $.attr(this, 'href')
		$root.animate({
			scrollTop: $(href).offset().top - 70
		}, 500, () ->
			# window.location.hash = href
		)
	)
