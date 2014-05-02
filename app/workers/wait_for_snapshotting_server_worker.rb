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
			droplet.destroy
			# TODO: digital ocean destroy droplet, update pending operation
		else
			WaitForSnapshottingServerWorker.perform_in(4.seconds, droplet_id, digital_ocean_event_id)
		end
	end

end
