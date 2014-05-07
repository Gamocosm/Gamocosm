class WaitForStartingServerWorker
	include Sidekiq::Worker
	sidekiq_options queue: 'high'
	sidekiq_options retry: 3

	def perform(user_id, droplet_id, digital_ocean_event_id)
		user = User.find(user_id)
		if user.digital_ocean.nil?
			raise "Error getting digital ocean for user #{user_id}"
		end
		droplet = Droplet.find(droplet_id)
		event = DigitalOcean::Event.new(digital_ocean_event_id, user)
		if event.has_error?
			raise "Error getting digital ocean event #{digital_ocean_event_id}, #{event}"
		end
		if event.is_done?
			# TODO: setup server
			droplet.minecraft_server.update_columns(pending_operation: nil)
		else
			WaitForStartingServerWorker.perform_in(4.seconds, user_id, droplet_id, digital_ocean_event_id)
		end
	end

end
