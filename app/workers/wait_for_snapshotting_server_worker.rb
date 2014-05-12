class WaitForSnapshottingServerWorker
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
			raise "Error getting event #{digital_ocean_event_id}, #{event}"
		end
		if event.is_done?
			snapshots = droplet.remote.list_snapshots
			snapshots.sort! { |a, b| a.id <=> b.id }
			droplet.minecraft_server.update_columns(saved_snapshot_id: snapshots[-1].id)
			response = user.digital_ocean.droplets.delete(droplet.remote_id)
			if response.status != 'OK'
				raise "Error deleting droplet #{droplet.id} for minecraft server #{droplet.minecraft_server_id} on digital ocean, response was #{response}"
			end
			droplet.minecraft_server.update_columns(pending_operation: nil, digital_ocean_pending_event_id: nil)
			droplet.destroy
		else
			WaitForSnapshottingServerWorker.perform_in(4.seconds, droplet_id, digital_ocean_event_id)
		end
	rescue ActiveRecord::RecordNotFound => e
		Rails.logger.info "Record in worker not found #{e.message}"
	end

end
