# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
#
(($) ->
	$ ->
		do_volumes = $('#digital_ocean_volumes')
		do_snapshots = $('#digital_ocean_snapshots')
		do_ssh_keys = $('#digital_ocean_ssh_keys')
		if do_volumes.length
			$.ajax
				url: do_volumes.data('url')
				dataType: 'html'
				timeout: 8 * 1000
				type: 'GET'
				success: (data, textStatus, jqXHR) ->
					do_volumes.html(data)
				error: (jqXHR, textStatus, errorThrown) ->
					do_volumes.find('td').html("Unable to get Digital Ocean volumes (#{textStatus})")
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
)(jQuery)
