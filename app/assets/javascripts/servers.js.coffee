# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

(($) ->
	$ ->
		minecraft_flavour = $('#server_minecraft_attributes_flavour')
		minecraft_flavour_update = () ->
			flavours = $('.minecraft_flavour-info')
			flavours.hide()
			flavours.filter('[data-flavour="' + minecraft_flavour.val() + '"]').show()
		minecraft_flavour_update()
		minecraft_flavour.on('change', minecraft_flavour_update)

		do_droplets = $('#digital_ocean_droplets')
		do_snapshots = $('#digital_ocean_snapshots')
		do_ssh_keys = $('#digital_ocean_ssh_keys')
		if do_droplets.length
			$.ajax
				url: do_droplets.data('url')
				dataType: 'html'
				timeout: 8 * 1000
				type: 'GET'
				success: (data, textStatus, jqXHR) ->
					do_droplets.html(data)
				error: (jqXHR, textStatus, errorThrown) ->
					do_droplets.find('td').html("Unable to get Digital Ocean droplets (#{textStatus})")
		if do_snapshots.length
			$.ajax
				url: do_snapshots.data('url')
				dataType: 'html'
				timeout: 8 * 1000
				type: 'GET'
				success: (data, textStatus, jqXHR) ->
					do_snapshots.html(data)
				error: (jqXHR, textStatus, errorThrown) ->
					do_snapshots.find('td').html("Unable to get Digital Ocean snapshots (#{textStatus})")
		if do_ssh_keys.length
			$.ajax
				url: do_ssh_keys.data('url')
				dataType: 'html'
				timeout: 8 * 1000
				type: 'GET'
				success: (data, textStatus, jqXHR) ->
					do_ssh_keys.html(data)
				error: (jqXHR, textStatus, errorThrown) ->
					do_ssh_keys.find('td').html("Unable to get Digital Ocean SSH keys (#{textStatus})")
)(jQuery)
