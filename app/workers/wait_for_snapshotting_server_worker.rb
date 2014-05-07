class WaitForSnapshottingServerWorker
	include Sidekiq::Worker
	sidekiq_options queue: 'high'
	sidekiq_options retry: 3

	def perform(user_id, droplet_id, digital_ocean_event_id)
		user = User.find(user_id)
		if user.digital_ocean.nil?
			raise "Error getting digital ocean for user #{user_id}"
		end
		droplet = Droplet.find(droplet_id)
		event = new DigitalOcean::Event.new(digital_ocean_event_id, user)
		if event.has_error?
			raise "Error getting event #{digital_ocean_event_id}, #{event}"
		end
		if event.is_done?
			snapshots = user.digital_ocean_snapshots
			snapshots.sort! { |a, b| a.id <=> b.id }
			droplet.minecraft_server.update_columns(saved_snapshot_id: snapshots[-1].id)
			response = user.digital_ocean.destroy(droplet.remote_id)
			if response.status != 'OK'
				# TODO: error
			end
			if droplet.minecraft_server.should_destroy
				droplet.minecraft_server.destroy
			else
				droplet.minecraft_server.update_columns(pending_operation: nil)
			end
		else
			WaitForSnapshottingServerWorker.perform_in(4.seconds, droplet_id, digital_ocean_event_id)
		end
	end

end
