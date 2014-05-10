class WaitForStartingServerWorker
	include Sidekiq::Worker
	sidekiq_options retry: 4
	sidekiq_retry_in do |count|
		4
	end

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
			droplet.update_columns(remote_id: event.data['droplet_id'])
			if !droplet.remote.sync
				raise "Error syncing droplet #{droplet.id}"
			end
			#droplet.remote.rename
			if droplet.minecraft_server.remote_setup_stage == 0
				SetupServerWorker.perform_in(4.seconds, user_id, droplet_id)
			else
				droplet.minecraft_server.resume
				droplet.minecraft_server.update_columns(pending_operation: nil)
			end
		else
			WaitForStartingServerWorker.perform_in(4.seconds, user_id, droplet_id, digital_ocean_event_id)
		end
	end

end
