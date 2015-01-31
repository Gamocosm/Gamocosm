# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

(($) ->
	$ ->
		minecraft_flavour = $('#minecraft_flavour')
		minecraft_flavour_update = () ->
			flavours = $('.minecraft_flavour-info')
			flavours.hide()
			flavours.filter('[data-flavour="' + minecraft_flavour.val() + '"]').show()
		minecraft_flavour_update()
		minecraft_flavour.on('change', minecraft_flavour_update)
)(jQuery)
